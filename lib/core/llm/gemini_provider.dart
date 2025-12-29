import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'llm_provider.dart';

class GeminiProvider implements LLMProvider {
  final String apiKey;

  GeminiProvider({required this.apiKey});

  Uri _generateContentUri(String model) {
    return Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );
  }

  Uri _streamGenerateContentUri(String model) {
    return Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:streamGenerateContent?alt=sse&key=$apiKey',
    );
  }

  Map<String, dynamic> _body(List<Map<String, dynamic>> content) {
    return {
      'contents': [
        {'parts': content}
      ]
    };
  }

  String _extractTextFromResponse(Map<String, dynamic> data) {
    final candidates = (data['candidates'] as List?) ?? const [];
    if (candidates.isEmpty) return '';

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final parts = (content?['parts'] as List?) ?? const [];
    if (parts.isEmpty) return '';

    final text = parts[0]['text'];
    return text is String ? text : '';
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

  @override
  Future<String> chatWithContent({
    required List<Map<String, dynamic>> content,
    required String model,
    bool isThinkingModel = false,
  }) async {
    final uri = _generateContentUri(model);

    final res = await http.post(
      uri,
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
      },
      body: jsonEncode(_body(content)),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Gemini error ${res.statusCode}: ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    String responseContent = _extractTextFromResponse(data);

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
    final uri = _streamGenerateContentUri(model);

    final client = HttpClient();
    try {
      final req = await client.postUrl(uri);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');

      req.write(jsonEncode(_body(content)));

      final res = await req.close();

      if (res.statusCode < 200 || res.statusCode >= 300) {
        final body = await res.transform(utf8.decoder).join();
        throw Exception('Gemini stream error ${res.statusCode}: $body');
      }

      await for (final line
          in res.transform(utf8.decoder).transform(const LineSplitter())) {
        if (!line.startsWith('data:')) continue;

        final payload = line.substring(5).trim();
        if (payload.isEmpty) continue;

        Map<String, dynamic> obj;
        try {
          obj = jsonDecode(payload) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }

        String text = _extractTextFromResponse(obj);
        if (text.isNotEmpty) {
          if (isThinkingModel) {
            text = text.replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '');
          }
          yield text;
        }
      }
    } finally {
      client.close(force: true);
    }
  }
}
