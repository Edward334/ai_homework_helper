import 'package:flutter/foundation.dart';

import '../../ui/settings/models.dart';
import 'channel_persistence.dart';

class ChannelStore extends ChangeNotifier {
  List<ChannelConfig> channels;

  ChannelStore(this.channels);

  /// 当前默认渠道
  ChannelConfig get defaultChannel =>
      channels.firstWhere((c) => c.isDefault);

  /// ===== 启动时加载 =====
  static Future<ChannelStore> load() async {
    final list = await ChannelPersistence.load();

    if (list.isEmpty) {
      return ChannelStore([
        ChannelConfig(
          name: '默认 OpenAI',
          type: ChannelType.openai,
          apiUrl: 'https://api.openai.com/v1',
          apiKey: '',
          models: ['gpt-4o-mini'],
          selectedModel: 'gpt-4o-mini',
          isDefault: true,
        ),
      ]);
    }

    return ChannelStore(list);
  }

  /// ===== 显式保存（关键）=====
  void save() {
    ChannelPersistence.save(channels);
  }

  /// 设为默认渠道
  void setDefault(ChannelConfig channel) {
    for (final c in channels) {
      c.isDefault = false;
    }
    channel.isDefault = true;
    save();
    notifyListeners();
  }

  /// 新增渠道
  void addChannel(ChannelConfig channel) {
    channels.add(channel);
    save();
    notifyListeners();
  }

  /// 删除渠道
  void removeChannel(ChannelConfig channel) {
    if (channel.isDefault || channels.length <= 1) return;
    channels.remove(channel);
    save();
    notifyListeners();
  }
}
