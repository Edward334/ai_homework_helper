import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'history_models.dart';

class HistoryStore {
  static const String _fileName = 'history.json';
  static const int _maxRecords = 200;

  static Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<List<HistoryRecord>> loadAll() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      final List<dynamic> list = jsonDecode(content) as List<dynamic>;
      final records = list
          .map((e) => HistoryRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return records;
    } catch (_) {
      return [];
    }
  }

  static Future<void> add(HistoryRecord record) async {
    final records = await loadAll();
    records.removeWhere((r) => r.id == record.id);
    records.insert(0, record);
    if (records.length > _maxRecords) {
      records.removeRange(_maxRecords, records.length);
    }
    await _saveAll(records);
  }

  static Future<void> delete(String id) async {
    final records = await loadAll();
    records.removeWhere((r) => r.id == id);
    await _saveAll(records);
  }

  static Future<void> clear() async {
    await _saveAll([]);
  }

  static Future<void> _saveAll(List<HistoryRecord> records) async {
    final file = await _getFile();
    final content = jsonEncode(records.map((e) => e.toJson()).toList());
    await file.writeAsString(content, flush: true);
  }
}
