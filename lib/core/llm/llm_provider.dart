abstract class LLMProvider {
  Future<String> chat({
    required String prompt,
    required String model,
  });

  Stream<String> chatStream({
    required String prompt,
    required String model,
  });

  Future<String> chatWithContent({
    required List<Map<String, dynamic>> content,
    required String model,
    bool isThinkingModel = false,
  });

  Stream<String> chatStreamWithContent({
    required List<Map<String, dynamic>> content,
    required String model,
    bool isThinkingModel = false,
  });
}