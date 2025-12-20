import 'package:flutter/material.dart';

class ResultPage extends StatefulWidget {
  const ResultPage({super.key});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  int selectedIndex = 0;

  final questions = [
    '解方程：x² + 3x + 2 = 0',
    '求函数的最值',
    '证明题示例',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('搜题结果')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // 宽屏：PC / 平板横屏
          if (constraints.maxWidth > 700) {
            return _buildDesktop();
          }
          // 窄屏：手机
          return _buildMobile();
        },
      ),
    );
  }

  // ================= PC 布局 =================
  Widget _buildDesktop() {
    return Row(
      children: [
        // 左侧题目列表
        Container(
          width: 240,
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: Colors.grey.shade300)),
          ),
          child: ListView.builder(
            itemCount: questions.length,
            itemBuilder: (context, index) {
              return ListTile(
                selected: index == selectedIndex,
                title: Text('第 ${index + 1} 题'),
                subtitle: Text(questions[index]),
                onTap: () {
                  setState(() => selectedIndex = index);
                },
              );
            },
          ),
        ),

        // 右侧内容
        Expanded(child: _buildContent()),
      ],
    );
  }

  // ================= 手机布局 =================
  Widget _buildMobile() {
    return Column(
      children: [
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: questions.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ChoiceChip(
                  label: Text('第 ${index + 1} 题'),
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

  // ================= 题目 + 答案 + 解析 =================
  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Text(
            '题目：\n${questions[selectedIndex]}',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 24),
          const Text(
            '答案：\n这里是答案内容',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          const Text(
            '解析：\n'
            '1. 分析题意\n'
            '2. 建立模型\n'
            '3. 推导步骤\n'
            '4. 得出结论',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
