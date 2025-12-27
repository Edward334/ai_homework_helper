import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'; // 导入 file_picker
import '../result/result_page.dart';
import '../settings/settings_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Widget _actionCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 56),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
      appBar: AppBar(
        title: const Text('作业帮'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '设置',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            _actionCard(
              icon: Icons.camera_alt,
              title: '拍照搜题',
              onTap: () async {
                // 模拟拍照，实际应用中需要集成相机功能
                // 这里为了演示，我将使用一个本地的图片文件路径作为示例
                // 请替换为实际的图片路径，或者实现相机拍照功能
                const String dummyImagePath = '/path/to/your/image.png'; // TODO: 替换为实际图片路径

                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ResultPage(filePath: dummyImagePath),
                  ),
                );
              },
            ),
            const SizedBox(width: 24),
            _actionCard(
              icon: Icons.picture_as_pdf,
              title: '上传 PDF',
              onTap: () async {
                FilePickerResult? result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['pdf'],
                );

                if (result != null && result.files.single.path != null) {
                  String filePath = result.files.single.path!;
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ResultPage(filePath: filePath),
                    ),
                  );
                } else {
                  // 用户取消了文件选择
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('未选择文件')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
