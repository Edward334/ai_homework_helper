import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../fs/app_paths.dart';
import 'app_settings.dart';

class AppSettingsStore extends ChangeNotifier {
  AppSettings _settings;

  AppSettingsStore(this._settings);

  AppSettings get settings => _settings;

  static Future<AppSettingsStore> load() async {
    try {
      final file = await AppPaths.appSettingsFile();
      if (!await file.exists()) {
        return AppSettingsStore(const AppSettings());
      }
      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        return AppSettingsStore(const AppSettings());
      }
      final data = jsonDecode(content) as Map<String, dynamic>;
      return AppSettingsStore(AppSettings.fromJson(data));
    } catch (_) {
      return AppSettingsStore(const AppSettings());
    }
  }

  void update({
    bool? enableQuestionClassification,
    int? maxConcurrentTasks,
  }) {
    _settings = _settings.copyWith(
      enableQuestionClassification: enableQuestionClassification,
      maxConcurrentTasks: maxConcurrentTasks,
    );
    save();
    notifyListeners();
  }

  Future<void> save() async {
    final file = await AppPaths.appSettingsFile();
    final content = jsonEncode(_settings.toJson());
    await file.writeAsString(content, flush: true);
  }
}
