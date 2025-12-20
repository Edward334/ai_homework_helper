import 'package:flutter/material.dart';

import '../settings/models.dart';
import '../../../core/llm/llm_client.dart';

enum QuestionStatus {
  loading,
  done,
  error,
}

class QuestionItem {
  final String title;
  QuestionStatus status;
  String? answer;

  QuestionItem({
    required this.title,
    this.status = QuestionStatus.loading,
    this.answer,
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

  /// ⚠️ 临时：当前默认渠道（下一步会统一管理）
  late ChannelConfig currentChannel;

  @override
  void initState() {
    super.initState();

    // ====== 假题目（来自 OCR / PDF）======
    questions = [
      QuestionItem(title: '解方程:x² + 3x + 2 = 0'),
      QuestionItem(title: '求函数的最值'),
      QuestionItem(title: '证明题示例'),
    ];

    // ====== 临时默认渠道（先能跑）======
    currentChannel = ChannelConfig(
      name: '默认 OpenAI',
      type: ChannelType.openai,
      apiUrl: 'https://yunwu.ai/v1',
      apiKey: 'sk-zzzzz', // 👈 先填你的 key
      models: ['gemini-2.5-flash'],
      selectedModel: 'gemini-2.5-flash',
      isDefault: true,
    );

    _loadAnswersWithLLM();
  }

  /// ================= 真实 LLM 调用 =================
  Future<void> _loadAnswersWithLLM() async {
    final provider = LLMClient.fromChannel(currentChannel);

    for (int i = 0; i < questions.length; i++) {
      try {
        final answer = await provider.chat(
          prompt: '''
你是一名耐心的作业辅导老师。
请逐步讲解下面这道题，并给出最终答案：

${questions[i].title}
''',
          model: currentChannel.selectedModel,
        );

        setState(() {
          questions[i].status = QuestionStatus.done;
          questions[i].answer = answer;
        });
      } catch (e) {
        setState(() {
          questions[i].status = QuestionStatus.error;
          questions[i].answer = e.toString();
        });
      }
    }
  }

  // =================================================

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
                onTap: () {
                  setState(() => selectedIndex = index);
                },
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
                  onSelected: (_) {
                    setState(() => selectedIndex = index);
                  },
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

    if (q.status == QuestionStatus.loading) {
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

    if (q.status == QuestionStatus.error) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          q.answer ?? '解析失败',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Text(
            '题目：\n${q.title}',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 24),
          const Text(
            '解析：',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(q.answer ?? ''),
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
