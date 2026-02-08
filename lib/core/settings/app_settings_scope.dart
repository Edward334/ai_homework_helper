import 'package:flutter/material.dart';

import 'app_settings_store.dart';

class AppSettingsScope extends InheritedNotifier<AppSettingsStore> {
  const AppSettingsScope({
    super.key,
    required AppSettingsStore super.notifier,
    required super.child,
  });

  static AppSettingsStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppSettingsScope>();
    assert(scope != null, 'AppSettingsScope not found');
    return scope!.notifier!;
  }
}
