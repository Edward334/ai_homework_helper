import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AppPaths {
  /// 应用支持目录
  static Future<Directory> appDir() async {
    return await getApplicationSupportDirectory();
  }

  /// 渠道配置 JSON 文件
  static Future<File> channelConfigFile() async {
    final dir = await appDir();

    final file = File('${dir.path}/channels.json');

    // 🔍 调试用（可留可删）
    // print('📁 Channel JSON path: ${file.path}');

    return file;
  }

  /// 应用设置 JSON 文件
  static Future<File> appSettingsFile() async {
    final dir = await appDir();
    return File('${dir.path}/app_settings.json');
  }
}
