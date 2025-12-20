abstract class LLMProvider {
  Future<String> chat({
    required String prompt,
    required String model,
  });
}
