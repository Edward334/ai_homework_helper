

import 'package:ai_homework_helper/core/llm/llm_provider.dart';
import 'package:ai_homework_helper/core/recognition/image_to_base64.dart';

class QuestionRecognizer {
  final LLMProvider llmProvider;
  final String model;

  QuestionRecognizer({required this.llmProvider, required this.model});

  static const String _prompt = """
请识别图片中的题目，并以以下 JSON 格式输出题目、答案和解析。
如果图片中包含多个题目，请将它们都识别出来。
如果无法识别，请返回一个空的题目列表。
请直接输出 JSON，不要包含任何额外的文字或解释。

输出格式：
{
  "questions": [
    {
      "question": "题目内容",
      "answer": "答案",
      "explanation": "解析"
    }
  ]
}
""";

  Future<String> recognizeQuestionFromImage(String imagePath) async {
    final String base64Image = await ImageToBase64.convert(imagePath);

    final List<Map<String, dynamic>> content = [
      {'text': _prompt},
      {
        'image_url': base64Image,
      },
    ];

    return await llmProvider.chatWithContent(
      content: content,
      model: model,
    );
  }

  Future<String> recognizeQuestionFromPdf(String pdfPath) async {
    // For PDF, we'll need to convert each page to an image first.
    // This is a placeholder. A real implementation would involve a PDF rendering library.
    // For now, we'll treat PDF as an image for simplicity, assuming the first page is enough
    // or that the LLM can handle a multi-image input if we convert all pages.
    // Given the current LLMProvider only takes one image_url per content part,
    // we'll assume a single image for now.
    // A more robust solution would involve:
    // 1. PDF to image conversion (e.g., using `pdf_render` or a native solution).
    // 2. Iterating through pages, converting each to an image.
    // 3. Sending multiple images to the LLM if supported, or processing each image separately.

    // Placeholder: For now, we'll just throw an unimplemented error.
    throw UnimplementedError('PDF recognition is not yet implemented.');
  }
}