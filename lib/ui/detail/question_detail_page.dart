import 'package:flutter/material.dart';
import 'package:ai_homework_helper/ui/result/question_card.dart';

class QuestionDetailPage extends StatelessWidget {
  final int index;
  final String title;

  const QuestionDetailPage({
    super.key,
    required this.index,
    required this.title,
  });

  Widget _buildSectionCard({required String title, required String content, required IconData icon}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue.shade700, size: 28),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF64B5F6), Color(0xFF42A5F5)], // Light Blue Gradient
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.description, color: Colors.white, size: 28),
            const SizedBox(width: 10),
            Text(
              '第 $index 题解析',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            QuestionCard(
              index: index,
              title: title,
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              icon: Icons.lightbulb_outline,
              title: '解析',
              content: '1. 分析题意\n2. 建立数学模型\n3. 逐步推导\n4. 得出结论',
            ),
          ],
        ),
      ),
    );
  }
}