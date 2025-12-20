import 'package:flutter/material.dart';
import 'channel_store.dart';

class ChannelScope extends InheritedNotifier<ChannelStore> {
  const ChannelScope({
    super.key,
    required ChannelStore super.notifier,
    required super.child,
  });

  static ChannelStore of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ChannelScope>();
    assert(scope != null, 'ChannelScope not found');
    return scope!.notifier!;
  }
}
