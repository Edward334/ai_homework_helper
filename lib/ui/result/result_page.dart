import 'dart:convert'; // 用于 JSON 解析
import 'package:flutter/material.dart';

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
      final Map<String, dynamic> data = jsonDecode(sanitizedJson);
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
      appBar: AppBar(title: const Text('搜题结果')),
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
}
