import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:path_provider/path_provider.dart';

import 'core/channel/channel_store.dart';
import 'core/channel/channel_scope.dart';
import 'core/settings/app_settings_scope.dart';
import 'core/settings/app_settings_store.dart';
import 'ui/home/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = await ChannelStore.load();
  final settingsStore = await AppSettingsStore.load();

  final dir = await getTemporaryDirectory();
  Pdfrx.getCacheDirectory = () => dir.path;

  runApp(MyApp(store: store, settingsStore: settingsStore));
}

class MyApp extends StatelessWidget {
  final ChannelStore store;
  final AppSettingsStore settingsStore;

  const MyApp({super.key, required this.store, required this.settingsStore});

  @override
  Widget build(BuildContext context) {
    return ChannelScope(
      notifier: store,
      child: AppSettingsScope(
        notifier: settingsStore,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: const HomePage(),
        ),
      ),
    );
  }
}
