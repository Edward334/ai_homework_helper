import 'dart:convert'; // 用于 JSON 解析
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../../core/channel/channel_scope.dart';
import '../../core/llm/llm_client.dart';
import '../../core/recognition/question_recognizer.dart'; // 导入 QuestionRecognizer
import '../../ui/settings/models.dart';
import '../common/markdown_view.dart';

enum QuestionStatus {
  loading,
  done,
  error,
}

class QuestionItem {
  final String title;
  QuestionStatus status;
  String answer;
  String explanation; // 新增：解析

  QuestionItem({
    required this.title,
    this.status = QuestionStatus.loading,
    this.answer = '',
    this.explanation = '', // 初始化
  });
}

class ResultPage extends StatefulWidget {
  final String filePath; // 新增：文件路径

  const ResultPage({super.key, required this.filePath}); // 修改构造函数

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  int selectedIndex = 0;
  List<QuestionItem> questions = []; // 初始化为空列表

  bool _exportIncludeQuestion = true;
  bool _exportIncludeAnswer = true;
  bool _exportIncludeExplanation = true;

  bool _started = false;
  late ChannelConfig _currentChannel;
  late QuestionRecognizer _questionRecognizer; // 新增：QuestionRecognizer

  String _sanitizeAiJson(String raw) {
    final trimmed = raw.trim();
    final fenceMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```', caseSensitive: false)
        .firstMatch(trimmed);
    if (fenceMatch != null && fenceMatch.groupCount >= 1) {
      return fenceMatch.group(1)!.trim();
    }
    return trimmed;
  }

  String _extractJsonPayload(String input) {
    final startObj = input.indexOf('{');
    final startArr = input.indexOf('[');
    int start;
    if (startObj == -1 && startArr == -1) return input;
    if (startObj == -1) {
      start = startArr;
    } else if (startArr == -1) {
      start = startObj;
    } else {
      start = startObj < startArr ? startObj : startArr;
    }

    int depth = 0;
    bool inString = false;
    bool escape = false;
    for (int i = start; i < input.length; i++) {
      final ch = input[i];
      if (escape) {
        escape = false;
        continue;
      }
      if (ch == '\\') {
        if (inString) {
          escape = true;
        }
        continue;
      }
      if (ch == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;

      if (ch == '{' || ch == '[') depth++;
      if (ch == '}' || ch == ']') {
        depth--;
        if (depth == 0) {
          return input.substring(start, i + 1);
        }
      }
    }
    return input;
  }

  String _escapeNewlinesInJsonStrings(String input) {
    final buffer = StringBuffer();
    bool inString = false;
    bool escape = false;
    for (int i = 0; i < input.length; i++) {
      final ch = input[i];
      if (escape) {
        buffer.write(ch);
        escape = false;
        continue;
      }
      if (ch == '\\') {
        buffer.write(ch);
        if (inString) escape = true;
        continue;
      }
      if (ch == '"') {
        inString = !inString;
        buffer.write(ch);
        continue;
      }
      if (inString && (ch == '\n' || ch == '\r')) {
        if (ch == '\r' && i + 1 < input.length && input[i + 1] == '\n') {
          i++;
        }
        buffer.write('\\n');
        continue;
      }
      buffer.write(ch);
    }
    return buffer.toString();
  }

  String _stripTrailingCommas(String input) {
    return input.replaceAll(RegExp(r',\s*(\}|\])'), r'$1');
  }

  String _repairUnescapedQuotesInJsonStrings(String input) {
    final buffer = StringBuffer();
    bool inString = false;
    bool escape = false;

    int i = 0;
    while (i < input.length) {
      final ch = input[i];

      if (escape) {
        buffer.write(ch);
        escape = false;
        i++;
        continue;
      }

      if (ch == '\\') {
        buffer.write(ch);
        if (inString) {
          escape = true;
        }
        i++;
        continue;
      }

      if (ch == '"') {
        if (!inString) {
          inString = true;
          buffer.write(ch);
          i++;
          continue;
        }

        // If this quote looks like it ends the string (next non-space is , } ]),
        // keep it. Otherwise, escape it to avoid unterminated strings.
        int j = i + 1;
        while (j < input.length && (input[j] == ' ' || input[j] == '\t' || input[j] == '\r' || input[j] == '\n')) {
          j++;
        }
        if (j >= input.length || input[j] == ',' || input[j] == '}' || input[j] == ']') {
          inString = false;
          buffer.write(ch);
        } else {
          buffer.write(r'\"');
        }
        i++;
        continue;
      }

      if (inString && (ch == '\n' || ch == '\r')) {
        if (ch == '\r' && i + 1 < input.length && input[i + 1] == '\n') {
          i++;
        }
        buffer.write(r'\n');
        i++;
        continue;
      }

      buffer.write(ch);
      i++;
    }

    if (inString) {
      buffer.write('"');
    }

    return buffer.toString();
  }

  @override
  void initState() {
    super.initState();
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
      String recognizedJson;
      // 根据文件类型调用不同的识别方法
      if (widget.filePath.endsWith('.pdf')) {
        recognizedJson = await _questionRecognizer.recognizeQuestionFromPdf(widget.filePath);
      } else {
        recognizedJson = await _questionRecognizer.recognizeQuestionFromImage(widget.filePath);
      }
      print('Raw recognizedJson: $recognizedJson'); // Add this line for debugging

      String sanitizedJson = _sanitizeAiJson(recognizedJson);
      sanitizedJson = _extractJsonPayload(sanitizedJson);
      sanitizedJson = _escapeNewlinesInJsonStrings(sanitizedJson);
      sanitizedJson = _stripTrailingCommas(sanitizedJson);
      Map<String, dynamic> data;
      try {
        data = jsonDecode(sanitizedJson);
      } catch (_) {
        final repaired = _repairUnescapedQuotesInJsonStrings(sanitizedJson);
        data = jsonDecode(repaired);
      }
      final List<dynamic> questionList = data['questions'] ?? [];

      if (!mounted) return;
      setState(() {
        questions = questionList.map((item) {
          return QuestionItem(
            title: item['question'] ?? '未知题目',
            answer: item['answer'] ?? '暂无答案',
            explanation: item['explanation'] ?? '暂无解析',
          );
        }).toList();
      });

      _loadAnswersStream(); // 继续加载答案流
    } catch (e) {
      if (!mounted) return;
      setState(() {
        questions = [
          QuestionItem(
            title: '识别失败',
            status: QuestionStatus.error,
            answer: '识别失败：$e',
            explanation: '',
          )
        ];
      });
      // print('识别失败：$e');
    }
  }

  Future<void> _loadAnswersStream() async {
    if (!mounted) return;
    setState(() {
      for (final q in questions) {
        q.status = QuestionStatus.done; // 假设识别成功后，直接标记为完成
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜题结果'),
        actions: [
          TextButton.icon(
            onPressed: questions.isEmpty ? null : _showExportDialog,
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
          child: ListView.builder(
            itemCount: questions.length,
            itemBuilder: (context, index) {
              final q = questions[index];
              return ListTile(
                selected: index == selectedIndex,
                title: Text('第 ${index + 1} 题'),
                subtitle: Text(q.title),
                trailing: _statusIcon(q.status),
                onTap: () => setState(() => selectedIndex = index),
              );
            },
          ),
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
          height: 64,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: questions.length,
            itemBuilder: (context, index) {
              final q = questions[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('第 ${index + 1} 题'),
                      const SizedBox(width: 4),
                      _statusIcon(q.status, small: true),
                    ],
                  ),
                  selected: index == selectedIndex,
                  onSelected: (_) => setState(() => selectedIndex = index),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _buildContent()),
      ],
    );
  }

  // ================= 内容区域 =================
  Widget _buildContent() {
    if (questions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在识别题目…'),
          ],
        ),
      );
    }

    final q = questions[selectedIndex];

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
      fontSize: 10.5,
      font: selectedFont,
      fontFallback: selectedFont == null ? const <pw.Font>[] : [selectedFont],
      lineSpacing: 1.2,
    );
    final sectionTitle = pw.TextStyle(
      fontSize: 12,
      fontWeight: pw.FontWeight.bold,
      font: selectedFont,
      fontFallback: selectedFont == null ? const <pw.Font>[] : [selectedFont],
      lineSpacing: 1.2,
    );
    final shouldShowQuestion = _exportIncludeQuestion;
    final shouldShowAnswer = _exportIncludeAnswer;
    final shouldShowExplanation = _exportIncludeExplanation;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        build: (context) {
          return [
            pw.Text('搜题结果', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            ...List.generate(questions.length, (index) {
              final q = questions[index];
              final blocks = <pw.Widget>[];
              blocks.add(pw.Text('第 ${index + 1} 题', style: sectionTitle));
              if (shouldShowQuestion) {
                blocks.add(pw.Text('题目：${q.title}', style: baseStyle));
              }
              if (shouldShowAnswer) {
                blocks.add(pw.Text('答案：', style: baseStyle));
                blocks.add(pw.Text(q.answer.isNotEmpty ? q.answer : '暂无答案', style: baseStyle));
              }
              if (shouldShowExplanation) {
                blocks.add(pw.Text('解析：', style: baseStyle));
                blocks.add(pw.Text(q.explanation.isNotEmpty ? q.explanation : '暂无解析', style: baseStyle));
              }
              blocks.add(pw.SizedBox(height: 12));
              blocks.add(pw.Divider());
              blocks.add(pw.SizedBox(height: 12));
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: blocks,
              );
            }),
          ];
        },
      ),
    );

    final bytes = await doc.save();
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await Printing.sharePdf(bytes: bytes, filename: '搜题结果.pdf');
    } else {
      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
        name: '搜题结果.pdf',
      );
    }
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
