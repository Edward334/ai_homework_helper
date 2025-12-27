import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'llm_provider.dart';

class OpenAIProvider implements LLMProvider {
  final String apiUrl; // e.g. https://api.openai.com/v1
  final String apiKey;

  OpenAIProvider({
    required this.apiUrl,
    required this.apiKey,
  });

  String _normalizeBase(String base) {
    // 避免重复斜杠
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }

  @override
  Future<String> chat({
    required String prompt,
    required String model,
  }) async {
    final base = _normalizeBase(apiUrl);
    final uri = Uri.parse('$base/chat/completions');

    final res = await http.post(
      uri,
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer $apiKey',
        HttpHeaders.contentTypeHeader: 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'user', 'content': Uri.encodeComponent(prompt)},
        ],
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('OpenAI error ${res.statusCode}: ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final choices = (data['choices'] as List?) ?? const [];
    if (choices.isEmpty) return '';
    final msg = choices[0]['message'] as Map<String, dynamic>?;
    return (msg?['content'] as String?) ?? '';
  }

  @override
  Stream<String> chatStream({
    required String prompt,
    required String model,
  }) async* {
    final base = _normalizeBase(apiUrl);
    final uri = Uri.parse('$base/chat/completions');

    final client = HttpClient();
    try {
      final req = await client.postUrl(uri);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');

      req.write(jsonEncode({
        'model': model,
        'stream': true,
        'messages': [
          {'role': 'user', 'content': Uri.encodeComponent(prompt)},
        ],
      }));

      final res = await req.close();

      if (res.statusCode < 200 || res.statusCode >= 300) {
        final body = await res.transform(utf8.decoder).join();
        throw Exception('OpenAI stream error ${res.statusCode}: $body');
      }

      // SSE: data: {json}\n\n ... data: [DONE]
      await for (final line
          in res.transform(utf8.decoder).transform(const LineSplitter())) {
        if (!line.startsWith('data:')) continue;

        final payload = line.substring(5).trim();
        if (payload.isEmpty) continue;
        if (payload == '[DONE]') break;

        Map<String, dynamic> obj;
        try {
          obj = jsonDecode(payload) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }

        final choices = (obj['choices'] as List?) ?? const [];
        if (choices.isEmpty) continue;

        final delta = choices[0]['delta'] as Map<String, dynamic>?;
        final content = delta?['content'];
        if (content is String && content.isNotEmpty) {
          yield content;
        }
      }
    } finally {
      client.close(force: true);
    }
  }
}