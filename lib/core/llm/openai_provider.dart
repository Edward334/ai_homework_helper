import 'dart:convert';
import 'package:http/http.dart' as http;
import 'llm_provider.dart';

class OpenAIProvider implements LLMProvider {
  final String apiUrl;
  final String apiKey;

  OpenAIProvider({
    required this.apiUrl,
    required this.apiKey,
  });

  @override
  Future<String> chat({
    required String prompt,
    required String model,
  }) async {
    final res = await http.post(
      Uri.parse('$apiUrl/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('OpenAI API error: ${res.body}');
    }

    final data = jsonDecode(res.body);
    return data['choices'][0]['message']['content'];
  }
}
