import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'llm_provider.dart';

class OpenAIProvider implements LLMProvider {
  final String apiUrl; // e.g. https://api.openai.com/v1
  final String apiKey;
  final Duration _requestTimeout = const Duration(seconds: 90);
  final int _maxAttempts = 3;

  OpenAIProvider({
    required this.apiUrl,
    required this.apiKey,
  });

  String _normalizeBase(String base) {
    // 避免重复斜杠
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }

  List<Map<String, dynamic>> _buildMessages(
      List<Map<String, dynamic>> content) {
    return [
      {
        'role': 'user',
        'content': content.map((part) {
          if (part['text'] != null) {
            return {'type': 'text', 'text': part['text']};
          } else if (part['image_url'] != null) {
            return {
              'type': 'image_url',
              'image_url': {'url': part['image_url']}
            };
          }
          return {};
        }).toList(),
      }
    ];
  }

  @override
  Future<String> chat({
    required String prompt,
    required String model,
    bool isThinkingModel = false,
  }) async {
    return chatWithContent(
      content: [
        {'text': prompt}
      ],
      model: model,
      isThinkingModel: isThinkingModel,
    );
  }

  @override
  Stream<String> chatStream({
    required String prompt,
    required String model,
    bool isThinkingModel = false,
  }) async* {
    yield* chatStreamWithContent(
      content: [
        {'text': prompt}
      ],
      model: model,
      isThinkingModel: isThinkingModel,
    );
  }

  Future<http.Response> _postWithRetry(Uri uri, Map<String, String> headers, String body) async {
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        final res = await http
            .post(uri, headers: headers, body: body)
            .timeout(_requestTimeout);
        return res;
      } catch (e) {
        if (attempt >= _maxAttempts) rethrow;
        await Future.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
  }

  @override
  Future<String> chatWithContent({
    required List<Map<String, dynamic>> content,
    required String model,
    bool isThinkingModel = false,
  }) async {
    final base = _normalizeBase(apiUrl);
    final uri = Uri.parse('$base/chat/completions');

    final headers = <String, String>{
      HttpHeaders.authorizationHeader: 'Bearer $apiKey',
      HttpHeaders.contentTypeHeader: 'application/json',
      HttpHeaders.connectionHeader: 'close',
    };
    final body = jsonEncode({
      'model': model,
      'messages': _buildMessages(content),
    });

    final res = await _postWithRetry(uri, headers, body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('OpenAI error ${res.statusCode}: ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final choices = (data['choices'] as List?) ?? const [];
    if (choices.isEmpty) return '';
    final msg = choices[0]['message'] as Map<String, dynamic>?;
    String responseContent = (msg?['content'] as String?) ?? '';

    if (isThinkingModel) {
      responseContent = responseContent.replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '');
    }
    return responseContent;
  }

  @override
  Stream<String> chatStreamWithContent({
    required List<Map<String, dynamic>> content,
    required String model,
    bool isThinkingModel = false,
  }) async* {
    final base = _normalizeBase(apiUrl);
    final uri = Uri.parse('$base/chat/completions');

    final client = HttpClient();
    try {
      client.connectionTimeout = _requestTimeout;
      final req = await client.postUrl(uri);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.headers.set(HttpHeaders.connectionHeader, 'close');

      req.write(jsonEncode({
        'model': model,
        'stream': true,
        'messages': _buildMessages(content),
      }));

      final res = await req.close();

      if (res.statusCode < 200 || res.statusCode >= 300) {
        final body = await res.transform(utf8.decoder).join();
        throw Exception('OpenAI stream error ${res.statusCode}: $body');
      }

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
        String? content = delta?['content'];
        if (content is String && content.isNotEmpty) {
          if (isThinkingModel) {
            content = content.replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '');
          }
          yield content;
        }
      }
    } finally {
      client.close(force: true);
    }
  }
}
