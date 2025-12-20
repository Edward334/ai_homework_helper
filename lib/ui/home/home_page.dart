import 'package:flutter/material.dart';
import '../result/result_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Widget _actionCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Card(
          elevation: 3,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48),
                const SizedBox(height: 12),
                Text(title, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('作业帮')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            _actionCard(
              icon: Icons.camera_alt,
              title: '拍照搜题',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ResultPage(),
                  ),
                );
              },
            ),
            const SizedBox(width: 16),
            _actionCard(
              icon: Icons.picture_as_pdf,
              title: '上传 PDF',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ResultPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
