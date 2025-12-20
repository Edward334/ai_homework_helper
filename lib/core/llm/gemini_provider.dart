import 'dart:convert';
import 'package:http/http.dart' as http;
import 'llm_provider.dart';

class GeminiProvider implements LLMProvider {
  final String apiKey;

  GeminiProvider({required this.apiKey});

  @override
  Future<String> chat({
    required String prompt,
    required String model,
  }) async {
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';

    final res = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ]
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Gemini API error: ${res.body}');
    }

    final data = jsonDecode(res.body);
    return data['candidates'][0]['content']['parts'][0]['text'];
  }
}
