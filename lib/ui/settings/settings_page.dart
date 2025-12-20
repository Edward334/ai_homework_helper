import 'package:flutter/material.dart';
import 'models.dart';
import 'channel_edit_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final List<ChannelConfig> channels = [
    ChannelConfig(
      name: '默认 OpenAI',
      type: ChannelType.openai,
      apiUrl: 'https://api.openai.com/v1',
      apiKey: '',
      models: ['gpt-4o-mini', 'gpt-4.1'],
      selectedModel: 'gpt-4o-mini',
      isDefault: true,
    ),
  ];

  void _setDefault(ChannelConfig channel) {
    setState(() {
      for (final c in channels) {
        c.isDefault = false;
      }
      channel.isDefault = true;
    });
  }

  void _deleteChannel(ChannelConfig channel) {
    if (channel.isDefault || channels.length <= 1) return;

    setState(() {
      channels.remove(channel);
    });
  }

  @override
  Widget build(BuildContext context) {
    final defaultChannel =
        channels.firstWhere((c) => c.isDefault, orElse: () => channels.first);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '默认渠道',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ListTile(
            title: Text(defaultChannel.name),
            subtitle: Text(defaultChannel.selectedModel),
          ),

          const Divider(height: 32),

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
                      _setDefault(channel);
                    } else if (value == 'delete') {
                      _confirmDelete(context, channel);
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
                  setState(() {});
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

              setState(() {
                channels.add(newChannel);
              });
            },
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, ChannelConfig channel) {
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
              _deleteChannel(channel);
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
