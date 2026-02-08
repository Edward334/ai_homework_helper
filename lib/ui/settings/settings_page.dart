import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/channel/channel_scope.dart';
import '../../core/channel/channel_store.dart';
import '../../core/settings/app_settings_scope.dart';
import '../../core/settings/app_settings_store.dart';
import 'models.dart';
import 'channel_edit_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _maxConcurrentController = TextEditingController();
  final FocusNode _maxConcurrentFocus = FocusNode();
  bool _initialized = false;

  @override
  void dispose() {
    _maxConcurrentController.dispose();
    _maxConcurrentFocus.dispose();
    super.dispose();
  }

  void _initControllers(AppSettingsStore settingsStore) {
    if (_initialized) return;
    _initialized = true;
    _maxConcurrentController.text = settingsStore.settings.maxConcurrentTasks.toString();
    _maxConcurrentFocus.addListener(() {
      if (!_maxConcurrentFocus.hasFocus) {
        _commitMaxConcurrent(settingsStore);
      }
    });
  }

  void _commitMaxConcurrent(AppSettingsStore settingsStore) {
    final raw = _maxConcurrentController.text.trim();
    final value = int.tryParse(raw);
    if (value == null || value <= 0) {
      _maxConcurrentController.text = settingsStore.settings.maxConcurrentTasks.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('最大同时并发数需要为大于 0 的整数')),
      );
      return;
    }
    if (value != settingsStore.settings.maxConcurrentTasks) {
      settingsStore.update(maxConcurrentTasks: value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ChannelScope.of(context);
    final settingsStore = AppSettingsScope.of(context);
    _initControllers(settingsStore);
    final channels = store.channels;
    final defaultChannel = store.defaultChannel;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'AI 功能',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('是否开启题目分类'),
            subtitle: const Text('多页 PDF 会先进行大题分类'),
            value: settingsStore.settings.enableQuestionClassification,
            onChanged: (value) {
              settingsStore.update(enableQuestionClassification: value);
            },
          ),
          const SizedBox(height: 4),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('最大同时并发数'),
            subtitle: const Text('控制多页 PDF 解析时的并行任务数量'),
            trailing: SizedBox(
              width: 100,
              child: TextField(
                controller: _maxConcurrentController,
                focusNode: _maxConcurrentFocus,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.end,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _commitMaxConcurrent(settingsStore),
              ),
            ),
          ),

          const Divider(height: 32),

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
