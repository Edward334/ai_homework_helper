import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../../core/history/history_models.dart';
import '../../core/history/history_store.dart';

import '../../core/channel/channel_scope.dart';
import '../../core/llm/llm_client.dart';
import '../../core/recognition/question_recognizer.dart'; // 导入 QuestionRecognizer
import '../../core/settings/app_settings_scope.dart';
import '../../ui/settings/models.dart';
import '../common/markdown_view.dart';
import 'ai_json.dart';
import 'result_models.dart';

class _QuestionRef {
  final int groupIndex;
  final int questionIndex;

  const _QuestionRef(this.groupIndex, this.questionIndex);
}

class ResultPage extends StatefulWidget {
  final String? filePath; // 新增：文件路径
  final HistoryRecord? historyRecord;

  const ResultPage({super.key, required this.filePath}) : historyRecord = null; // 修改构造函数

  const ResultPage.fromHistory({super.key, required this.historyRecord}) : filePath = null;

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  int selectedIndex = 0;
  List<QuestionGroup> groups = [];
  List<_QuestionRef> _questionRefs = [];
  bool _isProcessing = false;
  String _loadingStage = '正在识别题目…';
  int _progressCurrent = 0;
  int _progressTotal = 0;

  bool _exportIncludeQuestion = true;
  bool _exportIncludeAnswer = true;
  bool _exportIncludeExplanation = true;
  bool _savedToHistory = false;

  bool _started = false;
  late ChannelConfig _currentChannel;
  late QuestionRecognizer _questionRecognizer; // 新增：QuestionRecognizer

  void _setLoadingStage(String stage, {int current = 0, int total = 0}) {
    if (!mounted) return;
    setState(() {
      _isProcessing = true;
      _loadingStage = stage;
      _progressCurrent = current;
      _progressTotal = total;
    });
  }

  void _finishProcessing() {
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
    });
  }

  void _rebuildQuestionRefs() {
    final refs = <_QuestionRef>[];
    for (int g = 0; g < groups.length; g++) {
      for (int q = 0; q < groups[g].questions.length; q++) {
        refs.add(_QuestionRef(g, q));
      }
    }
    _questionRefs = refs;
    if (selectedIndex >= _questionRefs.length) {
      selectedIndex = 0;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.historyRecord != null) {
      groups = _buildGroupsFromHistory(widget.historyRecord!);
      _rebuildQuestionRefs();
      _savedToHistory = true;
      _started = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    debugPrint('ResultPage didChangeDependencies context: $context');
    final scope = context.dependOnInheritedWidgetOfExactType<ChannelScope>();
    debugPrint('ChannelScope found in didChangeDependencies: $scope');

    _currentChannel = ChannelScope.of(context).defaultChannel;
    _questionRecognizer = QuestionRecognizer( // 初始化 QuestionRecognizer
      llmProvider: LLMClient.fromChannel(_currentChannel),
      model: _currentChannel.selectedModel,
      isThinkingModel: _currentChannel.isThinkingModel,
    );

    _recognizeAndLoadAnswers(); // 调用新的识别方法
  }

  Future<void> _recognizeAndLoadAnswers() async {
    try {
      // 根据文件类型调用不同的识别方法
      final filePath = widget.filePath;
      if (filePath == null) {
        throw Exception('文件路径为空');
      }
      final settings = AppSettingsScope.of(context).settings;
      if (filePath.endsWith('.pdf')) {
        final pageCount = await _questionRecognizer.getPdfPageCount(filePath);
        if (settings.enableQuestionClassification) {
          _setLoadingStage('正在进行题目分类…');
          final classificationJson = await _questionRecognizer.classifyPdfQuestions(filePath);
          final classifiedGroups = _parseClassificationGroups(
            classificationJson,
            pageCount,
          );
          final groupsResult = await _recognizeGroupsFromPdf(
            pdfPath: filePath,
            groups: classifiedGroups,
            maxConcurrent: settings.maxConcurrentTasks,
          );
          if (!mounted) return;
          setState(() {
            groups = groupsResult;
            _rebuildQuestionRefs();
          });
        } else {
          _setLoadingStage('正在识别题目…');
          final recognizedJson = await _questionRecognizer.recognizeQuestionFromPdfPages(
            pdfPath: filePath,
            pages: List<int>.generate(pageCount, (i) => i + 1),
            groupTitle: '题目',
            subject: '',
          );
          final items = AiJsonHelper.parseQuestions(recognizedJson);
          if (!mounted) return;
          setState(() {
            groups = [
              QuestionGroup(
                title: '题目',
                subject: '',
                pages: List<int>.generate(pageCount, (i) => i + 1),
                questions: items,
              ),
            ];
            _rebuildQuestionRefs();
          });
        }
      } else {
        _setLoadingStage('正在识别题目…');
        final recognizedJson = await _questionRecognizer.recognizeQuestionFromImage(filePath);
        final items = AiJsonHelper.parseQuestions(recognizedJson);
        if (!mounted) return;
        setState(() {
          groups = [
            QuestionGroup(
              title: '题目',
              subject: '',
              pages: const [],
              questions: items,
            ),
          ];
          _rebuildQuestionRefs();
        });
      }

      await _saveHistoryOnce();
      _finishProcessing();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        groups = [
          QuestionGroup(
            title: '识别失败',
            subject: '',
            pages: const [],
            questions: [
              QuestionItem(
                title: '识别失败',
                status: QuestionStatus.error,
                answer: '识别失败：$e',
                explanation: '',
              ),
            ],
          ),
        ];
        _rebuildQuestionRefs();
      });
      _finishProcessing();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜题结果'),
        actions: [
          TextButton.icon(
            onPressed: _questionRefs.isEmpty ? null : _showExportDialog,
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('导出 PDF'),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 700) {
            return _buildDesktop();
          }
          return _buildMobile();
        },
      ),
    );
  }

  // ================= PC 布局 =================
  Widget _buildDesktop() {
    return Row(
      children: [
        Container(
          width: 260,
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: Colors.grey.shade300)),
          ),
          child: _buildNavigationList(dense: false),
        ),
        Expanded(child: _buildContent()),
      ],
    );
  }

  // ================= 手机布局 =================
  Widget _buildMobile() {
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: _buildNavigationList(dense: true),
        ),
        const Divider(height: 1),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildNavigationList({required bool dense}) {
    if (_questionRefs.isEmpty) {
      return _buildLoadingStatus();
    }
    final items = <Widget>[];
    int globalIndex = 0;
    for (int g = 0; g < groups.length; g++) {
      final group = groups[g];
      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            group.displayTitle,
            style: TextStyle(
              fontSize: dense ? 13 : 14,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey.shade700,
            ),
          ),
        ),
      );
      for (int q = 0; q < group.questions.length; q++) {
        final question = group.questions[q];
        final currentIndex = globalIndex;
        items.add(
          ListTile(
            dense: dense,
            selected: currentIndex == selectedIndex,
            title: Text('第 ${currentIndex + 1} 题'),
            subtitle: Text(question.title, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: _statusIcon(question.status, small: dense),
            onTap: () => setState(() => selectedIndex = currentIndex),
          ),
        );
        globalIndex++;
      }
    }
    return ListView(children: items);
  }

  // ================= 内容区域 =================
  Widget _buildContent() {
    if (_questionRefs.isEmpty) {
      return _buildLoadingStatus();
    }

    final ref = _questionRefs[selectedIndex];
    final group = groups[ref.groupIndex];
    final q = group.questions[ref.questionIndex];

    // 还没收到任何 chunk 时，显示 loading 占位
    if (q.status == QuestionStatus.loading && q.answer.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在识别题目…'), // 修改提示
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Text(
            group.displayTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            '题目：${q.title}',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 16),
          if (q.status == QuestionStatus.error)
            Text(
              q.answer, // 错误信息
              style: const TextStyle(color: Colors.red),
            )
          else ...[
            const Text(
              '答案：',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            MarkdownView(q.answer),
            const SizedBox(height: 16),
            const Text(
              '解析：',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            MarkdownView(q.explanation),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingStatus() {
    final showProgress = _progressTotal > 0;
    final progressText = showProgress ? ' ($_progressCurrent/$_progressTotal)' : '';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('$_loadingStage$progressText'),
        ],
      ),
    );
  }

  // ================= 状态图标 =================
  Widget _statusIcon(QuestionStatus status, {bool small = false}) {
    final size = small ? 16.0 : 20.0;

    switch (status) {
      case QuestionStatus.loading:
        return SizedBox(
          width: size,
          height: size,
          child: const CircularProgressIndicator(strokeWidth: 2),
        );
      case QuestionStatus.done:
        return Icon(Icons.check_circle, color: Colors.green, size: size);
      case QuestionStatus.error:
        return Icon(Icons.error, color: Colors.red, size: size);
    }
  }

  Future<void> _saveHistoryOnce() async {
    if (_savedToHistory) return;
    if (widget.filePath == null || _questionRefs.isEmpty) return;

    final now = DateTime.now();
    final historyQuestions = <HistoryQuestion>[];
    for (final group in groups) {
      for (final q in group.questions) {
        historyQuestions.add(
          HistoryQuestion(
            question: q.title,
            answer: q.answer,
            explanation: q.explanation,
            groupTitle: group.displayTitle,
          ),
        );
      }
    }
    final record = HistoryRecord(
      id: now.microsecondsSinceEpoch.toString(),
      createdAt: now,
      sourcePath: widget.filePath!,
      sourceName: p.basename(widget.filePath!),
      questions: historyQuestions,
    );
    await HistoryStore.add(record);
    _savedToHistory = true;
  }

  Future<void> _showExportDialog() async {
    final theme = Theme.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) {
        bool includeQuestion = _exportIncludeQuestion;
        bool includeAnswer = _exportIncludeAnswer;
        bool includeExplanation = _exportIncludeExplanation;

        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('导出选项'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('字体：Noto Sans CJK SC（内置）'),
                  ),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: includeQuestion,
                    title: const Text('带题目'),
                    onChanged: (value) {
                      if (value == null) return;
                      setLocalState(() => includeQuestion = value);
                    },
                  ),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: includeAnswer,
                    title: const Text('带答案'),
                    onChanged: (value) {
                      if (value == null) return;
                      setLocalState(() => includeAnswer = value);
                    },
                  ),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: includeExplanation,
                    title: const Text('带解析'),
                    onChanged: (value) {
                      if (value == null) return;
                      setLocalState(() => includeExplanation = value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _exportIncludeQuestion = includeQuestion;
                      _exportIncludeAnswer = includeAnswer;
                      _exportIncludeExplanation = includeExplanation;
                    });
                    Navigator.of(context).pop();
                    _exportPdf();
                  },
                  child: const Text('导出 PDF'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportPdf() async {
    final pw.Font? selectedFont = await _loadBundledFont();
    if (selectedFont == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('字体文件缺失，请确认已放入 assets/fonts/')),
      );
      return;
    }

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: selectedFont,
        bold: selectedFont,
        italic: selectedFont,
        boldItalic: selectedFont,
      ),
    );
    final baseStyle = pw.TextStyle(
      fontSize: 9.5,
      font: selectedFont,
      fontFallback: [selectedFont],
      lineSpacing: 1.1,
    );
    final sectionTitle = pw.TextStyle(
      fontSize: 10.5,
      fontWeight: pw.FontWeight.bold,
      font: selectedFont,
      fontFallback: [selectedFont],
      lineSpacing: 1.1,
    );
    final shouldShowQuestion = _exportIncludeQuestion;
    final shouldShowAnswer = _exportIncludeAnswer;
    final shouldShowExplanation = _exportIncludeExplanation;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        build: (context) {
          final content = <pw.Widget>[
            pw.Text('搜题结果', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, font: selectedFont)),
            pw.SizedBox(height: 8),
          ];

          int globalIndex = 0;
          for (final group in groups) {
            content.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 6, bottom: 6),
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFEAF1F8),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(group.displayTitle, style: sectionTitle),
              ),
            );
            for (final q in group.questions) {
              final blocks = <pw.Widget>[];
              blocks.add(
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFFEFF2F5),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Text('第 ${globalIndex + 1} 题', style: sectionTitle),
                    ),
                  ],
                ),
              );
              blocks.add(pw.SizedBox(height: 6));
              if (shouldShowQuestion) {
                blocks.add(pw.Text('题目：${q.title}', style: baseStyle));
              }
              if (shouldShowAnswer) {
                blocks.add(pw.SizedBox(height: 4));
                blocks.add(pw.Text('答案：', style: baseStyle));
                blocks.add(pw.Text(q.answer.isNotEmpty ? q.answer : '暂无答案', style: baseStyle));
              }
              if (shouldShowExplanation) {
                blocks.add(pw.SizedBox(height: 4));
                blocks.add(pw.Text('解析：', style: baseStyle));
                blocks.add(pw.Text(q.explanation.isNotEmpty ? q.explanation : '暂无解析', style: baseStyle));
              }
              content.add(
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFF8F9FB),
                    border: pw.Border.all(color: PdfColor.fromInt(0xFFE1E6EB), width: 0.6),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: blocks,
                  ),
                ),
              );
              globalIndex++;
            }
          }
          return content;
        },
      ),
    );

    final bytes = await doc.save();
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await Printing.sharePdf(bytes: bytes, filename: '搜题结果.pdf');
      return;
    }

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: '保存搜题结果',
      fileName: '搜题结果.pdf',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (savePath == null) return;

    final file = File(savePath);
    await file.writeAsBytes(bytes, flush: true);
  }

  List<QuestionGroup> _buildGroupsFromHistory(HistoryRecord record) {
    final groupsMap = <String, QuestionGroup>{};
    for (final q in record.questions) {
      final title = q.groupTitle.trim().isEmpty ? '题目' : q.groupTitle.trim();
      final group = groupsMap.putIfAbsent(
        title,
        () => QuestionGroup(
          title: title,
          subject: '',
          pages: const [],
          questions: [],
        ),
      );
      group.questions.add(
        QuestionItem(
          title: q.question,
          answer: q.answer,
          explanation: q.explanation,
          status: QuestionStatus.done,
        ),
      );
    }
    return groupsMap.values.toList();
  }

  List<QuestionGroup> _parseClassificationGroups(String raw, int pageCount) {
    final data = AiJsonHelper.decodeObject(raw);
    final List<dynamic> list = data['groups'] ?? [];
    final groupsWithIndex = <MapEntry<int, QuestionGroup>>[];
    final assignedPages = <int>{};

    for (final item in list) {
      if (item is! Map<String, dynamic>) continue;
      final rawIndex = item['index'];
      final index = rawIndex is int ? rawIndex : int.tryParse('$rawIndex') ?? 0;
      final title = (item['title'] ?? '').toString().trim();
      final subject = (item['subject'] ?? '').toString().trim();
      final pagesRaw = item['pages'];
      final pages = <int>[];
      if (pagesRaw is List) {
        for (final p in pagesRaw) {
          final parsed = p is int ? p : int.tryParse('$p');
          if (parsed != null && parsed >= 1 && parsed <= pageCount && !assignedPages.contains(parsed)) {
            pages.add(parsed);
            assignedPages.add(parsed);
          }
        }
      }
      if (pages.isEmpty) continue;
      groupsWithIndex.add(
        MapEntry(
          index,
        QuestionGroup(
          title: title.isEmpty ? '第一大题：综合' : title,
          subject: subject,
          pages: pages,
          questions: [],
        ),
        ),
      );
    }

    final missingPages = <int>[];
    for (int i = 1; i <= pageCount; i++) {
      if (!assignedPages.contains(i)) {
        missingPages.add(i);
      }
    }
    if (missingPages.isNotEmpty) {
      groupsWithIndex.add(
        MapEntry(
          groupsWithIndex.length + 1,
        QuestionGroup(
          title: '补充大题',
          subject: '',
          pages: missingPages,
          questions: [],
        ),
        ),
      );
    }

    if (groupsWithIndex.isEmpty) {
      return [
        QuestionGroup(
          title: '第一大题：综合',
          subject: '',
          pages: List<int>.generate(pageCount, (i) => i + 1),
          questions: [],
        ),
      ];
    }

    groupsWithIndex.sort((a, b) => a.key.compareTo(b.key));
    return groupsWithIndex.map((e) => e.value).toList();
  }

  Future<List<QuestionGroup>> _recognizeGroupsFromPdf({
    required String pdfPath,
    required List<QuestionGroup> groups,
    required int maxConcurrent,
  }) async {
    final total = groups.length;
    int done = 0;
    _setLoadingStage('正在完成题目…', current: done, total: total);

    final tasks = <Future<List<QuestionItem>> Function()>[];
    for (final group in groups) {
      tasks.add(() async {
        try {
          final recognizedJson = await _questionRecognizer.recognizeQuestionFromPdfPages(
            pdfPath: pdfPath,
            pages: group.pages,
            groupTitle: group.title,
            subject: group.subject,
          );
          return AiJsonHelper.parseQuestions(recognizedJson);
        } catch (e) {
          return [
            QuestionItem(
              title: '识别失败',
              status: QuestionStatus.error,
              answer: '识别失败：$e',
              explanation: '',
            ),
          ];
        }
      });
    }

    final results = await _runWithConcurrency<List<QuestionItem>>(
      tasks,
      maxConcurrent,
      onProgress: (value) {
        done = value;
        _setLoadingStage('正在完成题目…', current: done, total: total);
      },
    );

    final merged = <QuestionGroup>[];
    for (int i = 0; i < groups.length; i++) {
      final group = groups[i];
      merged.add(
        QuestionGroup(
          title: group.title,
          subject: group.subject,
          pages: group.pages,
          questions: results[i],
        ),
      );
    }
    return merged;
  }

  Future<List<T>> _runWithConcurrency<T>(
    List<Future<T> Function()> tasks,
    int maxConcurrent, {
    required ValueChanged<int> onProgress,
  }) async {
    final total = tasks.length;
    if (total == 0) return [];
    final results = List<T?>.filled(total, null);
    int nextIndex = 0;
    int finished = 0;

    Future<void> worker() async {
      while (true) {
        int taskIndex;
        if (nextIndex >= total) return;
        taskIndex = nextIndex;
        nextIndex++;
        results[taskIndex] = await tasks[taskIndex]();
        finished++;
        onProgress(finished);
      }
    }

    final workerCount = maxConcurrent <= 0 ? 1 : maxConcurrent;
    final workers = List.generate(
      workerCount > total ? total : workerCount,
      (_) => worker(),
    );
    await Future.wait(workers);
    return results.cast<T>();
  }

  Future<pw.Font?> _loadBundledFont() async {
    try {
      final data = await rootBundle.load('assets/fonts/NotoSansSC-VariableFont_wght.ttf');
      return pw.Font.ttf(data.buffer.asByteData());
    } catch (_) {
      return null;
    }
  }
}
