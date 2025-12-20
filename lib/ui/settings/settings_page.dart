import 'package:flutter/material.dart';

import '../../core/channel/channel_scope.dart';
import '../../core/channel/channel_store.dart';
import 'models.dart';
import 'channel_edit_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = ChannelScope.of(context);
    final channels = store.channels;
    final defaultChannel = store.defaultChannel;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ===== 默认渠道 =====
          const Text(
            '默认渠道',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ListTile(
            title: Text(defaultChannel.name),
            subtitle: Text(defaultChannel.selectedModel),
            leading: const Icon(Icons.check_circle, color: Colors.green),
          ),

          const Divider(height: 32),

          // ===== 渠道列表 =====
          const Text(
            '渠道列表',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          ...channels.map((channel) {
            return Card(
              child: ListTile(
                title: Text(channel.name),
                subtitle: Text(
                  '${channel.type.name.toUpperCase()} · ${channel.selectedModel}',
                ),
                leading: channel.isDefault
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'default') {
                      store.setDefault(channel);
                    } else if (value == 'delete') {
                      _confirmDelete(context, store, channel);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'default',
                      child: Text('设为默认'),
                    ),
                    if (!channel.isDefault && channels.length > 1)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          '删除',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChannelEditPage(channel: channel),
                    ),
                  );

                  // ✅ 关键：编辑完成后立刻保存
                  store.save();
                },
              ),
            );
          }),

          const SizedBox(height: 16),

          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('新增渠道'),
            onPressed: () async {
              final newChannel = ChannelConfig(
                name: '新渠道',
                type: ChannelType.openai,
                apiUrl: '',
                apiKey: '',
                models: [],
                selectedModel: '',
              );

              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChannelEditPage(channel: newChannel),
                ),
              );

              store.addChannel(newChannel);
            },
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    ChannelStore store,
    ChannelConfig channel,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除渠道'),
        content: Text('确定要删除「${channel.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              store.removeChannel(channel);
            },
            child: const Text(
              '删除',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
