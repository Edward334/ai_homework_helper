import 'package:flutter/material.dart';
import 'models.dart';

class ChannelEditPage extends StatefulWidget {
  final ChannelConfig channel;

  const ChannelEditPage({super.key, required this.channel});

  @override
  State<ChannelEditPage> createState() => _ChannelEditPageState();
}

class _ChannelEditPageState extends State<ChannelEditPage> {
  late TextEditingController nameCtrl;
  late TextEditingController urlCtrl;
  late TextEditingController keyCtrl;
  late TextEditingController modelCtrl;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.channel.name);
    urlCtrl = TextEditingController(text: widget.channel.apiUrl);
    keyCtrl = TextEditingController(text: widget.channel.apiKey);
    modelCtrl = TextEditingController();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    urlCtrl.dispose();
    keyCtrl.dispose();
    modelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final channel = widget.channel;

    return Scaffold(
      appBar: AppBar(title: const Text('编辑渠道')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: '渠道名称',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => channel.name = v,
          ),

          const SizedBox(height: 16),

          DropdownButtonFormField<ChannelType>(
            initialValue: channel.type,
            decoration: const InputDecoration(
              labelText: '渠道类型',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: ChannelType.openai,
                child: Text('OpenAI'),
              ),
              DropdownMenuItem(
                value: ChannelType.gemini,
                child: Text('Gemini'),
              ),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() => channel.type = v);
              }
            },
          ),

          const SizedBox(height: 16),

          TextField(
            controller: urlCtrl,
            decoration: const InputDecoration(
              labelText: 'API URL',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => channel.apiUrl = v,
          ),

          const SizedBox(height: 16),

          TextField(
            controller: keyCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'API Key',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => channel.apiKey = v,
          ),

          const Divider(height: 32),

          const Text(
            '模型列表',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          ...channel.models.map(
            (m) => RadioListTile<String>(
              title: Text(m),
              value: m,
              groupValue: channel.selectedModel,
              onChanged: (v) {
                if (v != null) {
                  setState(() => channel.selectedModel = v);
                }
              },
            ),
          ),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: modelCtrl,
                  decoration: const InputDecoration(
                    hintText: '新增模型名',
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  final v = modelCtrl.text.trim();
                  if (v.isNotEmpty) {
                    setState(() {
                      channel.models.add(v);
                      channel.selectedModel = v;
                      modelCtrl.clear();
                    });
                  }
                },
              ),
            ],
          ),

          if (!channel.isDefault)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                onPressed: () {
                  Navigator.pop(context, 'delete');
                },
                child: const Text('删除此渠道'),
              ),
            ),
        ],
      ),
    );
  }
}
