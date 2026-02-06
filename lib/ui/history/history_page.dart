import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/history/history_models.dart';
import '../../core/history/history_store.dart';
import '../result/result_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool _loading = true;
  List<HistoryRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final records = await HistoryStore.loadAll();
    if (!mounted) return;
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  String _formatDate(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('历史记录'),
        actions: [
          if (_records.isNotEmpty)
            IconButton(
              tooltip: '清空',
              icon: const Icon(Icons.delete_sweep),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('清空历史记录'),
                    content: const Text('确认要清空全部历史记录吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('取消'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('清空'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await HistoryStore.clear();
                  await _load();
                }
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? const Center(child: Text('暂无历史记录'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _records.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final record = _records[index];
                    final title = record.sourceName.isNotEmpty
                        ? record.sourceName
                        : (record.sourcePath.isNotEmpty ? p.basename(record.sourcePath) : '未命名');
                    final subtitle = '共 ${record.questions.length} 题 · ${_formatDate(record.createdAt)}';
                    return Card(
                      child: ListTile(
                        title: Text(title),
                        subtitle: Text(subtitle),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await HistoryStore.delete(record.id);
                            await _load();
                          },
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ResultPage.fromHistory(historyRecord: record),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
