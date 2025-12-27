import 'package:flutter/material.dart';

import 'core/channel/channel_store.dart';
import 'core/channel/channel_scope.dart';
import 'ui/home/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = await ChannelStore.load();

  runApp(MyApp(store: store));
}

class MyApp extends StatelessWidget {
  final ChannelStore store;

  const MyApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ChannelScope( // 将 ChannelScope 放在 MaterialApp 之外
      notifier: store,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: const HomePage(), // HomePage 现在可以访问 ChannelScope 了
      ),
    );
  }
}
