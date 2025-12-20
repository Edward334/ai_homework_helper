import 'package:flutter/material.dart';

class QuestionDetailPage extends StatelessWidget {
  final int index;
  final String title;

  const QuestionDetailPage({
    super.key,
    required this.index,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('第 $index 题解析')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              '题目：\n$title',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            const Text(
              '解析：\n'
              '1. 分析题意\n'
              '2. 建立数学模型\n'
              '3. 逐步推导\n'
              '4. 得出结论',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
