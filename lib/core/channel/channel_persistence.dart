import 'dart:convert';
import 'dart:io';

import '../../ui/settings/models.dart';
import '../fs/app_paths.dart';

class ChannelPersistence {
  static Future<List<ChannelConfig>> load() async {
    try {
      final file = await AppPaths.channelConfigFile();
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      final list = jsonDecode(content) as List;

      return list
          .map((e) => ChannelConfig.fromJson(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<ChannelConfig> channels) async {
    final file = await AppPaths.channelConfigFile();
    final json = jsonEncode(channels.map((e) => e.toJson()).toList());
    await file.writeAsString(json);
  }
}
