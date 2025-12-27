import 'package:flutter/material.dart';

import '../../core/channel/channel_scope.dart';
import '../../core/llm/llm_client.dart';
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

  QuestionItem({
    required this.title,
    this.status = QuestionStatus.loading,
    this.answer = '',
  });
}

class ResultPage extends StatefulWidget {
  const ResultPage({super.key});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  int selectedIndex = 0;
  late List<QuestionItem> questions;

  bool _started = false;
  late ChannelConfig _currentChannel; // 新增：存储获取到的 channel

  @override
  void initState() {
    super.initState();

    questions = [
      QuestionItem(title: '解方程：x² + 3x + 2 = 0'),
      QuestionItem(title: '求函数的最值'),
      QuestionItem(title: '证明题示例'),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    debugPrint('ResultPage didChangeDependencies context: $context');
    final scope = context.dependOnInheritedWidgetOfExactType<ChannelScope>();
    debugPrint('ChannelScope found in didChangeDependencies: $scope');

    // 在这里获取 channel 并存储
    _currentChannel = ChannelScope.of(context).defaultChannel;

    _loadAnswersStream();
  }

  Future<void> _loadAnswersStream() async {
    // 使用存储的 _currentChannel
    final provider = LLMClient.fromChannel(_currentChannel);

    for (final q in questions) {
      // 如果已完成/失败就跳过
      if (q.status != QuestionStatus.loading || q.answer.isNotEmpty) {
        continue;
      }

      try {
        // 让模型用 Markdown + LaTeX 输出
        final buffer = StringBuffer()
          ..writeln('你是一名老师')
          ..writeln('请使用 Markdown 输出：')
          ..writeln('请按“题目分析 → 解题步骤 → 最终答案 → 易错点”结构回答。')
          ..writeln()
          ..writeln('题目：')
          ..writeln(q.title);

        final prompt = buffer.toString();

        await for (final chunk in provider.chatStream(
          prompt: prompt,
          model: _currentChannel.selectedModel,
        )) {
          debugPrint('Received chunk: $chunk');
          if (!mounted) return;
          setState(() {
            q.answer += chunk;
          });
        }

        if (!mounted) return;
        setState(() {
          q.status = QuestionStatus.done;
        });
        print('''Final answer for ${q.title}:
${q.answer}'''); // Corrected print statement
      } catch (e) {
        if (!mounted) return;
        setState(() {
          q.status = QuestionStatus.error;
          q.answer = '解析失败：$e';
        });
        print('''Error answer for ${q.title}:
${q.answer}'''); // Corrected print statement
      }
    }
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
    final q = questions[selectedIndex];

    // 还没收到任何 chunk 时，显示 loading 占位
    if (q.status == QuestionStatus.loading && q.answer.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在解析本题…'),
          ],
        ),
      );
    }

    // 已经开始流式输出：边显示边转圈（更像产品）
    final showSpinner = q.status == QuestionStatus.loading && q.answer.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Text(
            '题目：\n${q.title}',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 16),
          if (showSpinner)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('生成中…'),
                ],
              ),
            ),
          if (q.status == QuestionStatus.error)
            Text(
              q.answer,
              style: const TextStyle(color: Colors.red),
            )
          else if (q.answer.isNotEmpty) // 只有当 answer 不为空时才显示 MarkdownView
          MarkdownView(q.answer),
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
