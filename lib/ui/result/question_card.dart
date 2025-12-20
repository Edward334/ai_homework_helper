import 'package:flutter/material.dart';
import '../detail/question_detail_page.dart';

class QuestionCard extends StatelessWidget {
  final int index;
  final String title;

  const QuestionCard({
    super.key,
    required this.index,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text('第 $index 题'),
        subtitle: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => QuestionDetailPage(
                index: index,
                title: title,
              ),
            ),
          );
        },
      ),
    );
  }
}
