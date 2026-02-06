import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'; // 导入 file_picker
import 'package:image_picker/image_picker.dart'; // 导入 image_picker
import '../result/result_page.dart';
import '../settings/settings_page.dart';
import '../history/history_page.dart';

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
            icon: const Icon(Icons.history),
            tooltip: '历史记录',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HistoryPage(),
                ),
              );
            },
          ),
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
                final ImagePicker picker = ImagePicker();
                try {
                  final XFile? image = await picker.pickImage(source: ImageSource.camera);

                  if (image != null) {
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ResultPage(filePath: image.path),
                      ),
                    );
                  } else {
                    // 用户取消了拍照
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('未拍照')),
                    );
                  }
                } catch (e) {
                  // 处理相机不可用或权限问题
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('无法启动相机: $e')),
                  );
                }
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
