

import 'dart:convert';
import 'dart:typed_data';

import 'package:ai_homework_helper/core/llm/llm_provider.dart';
import 'package:ai_homework_helper/core/recognition/image_to_base64.dart';
import 'package:pdfrx/pdfrx.dart';

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
    try {
            final PdfDocument pdfDocument = await PdfDocument.openFile(pdfPath);
      final List<Map<String, dynamic>> content = [
        {'text': _prompt},
      ];

      for (var i = 0; i < pdfDocument.pages.length; i++) {
                final PdfPage page = pdfDocument.pages[i];
        final PdfImage? pageImage = await page.render(
          width: 1024, // Render at a fixed width to optimize image size for LLM
        );

        if (pageImage == null) {
          continue; // 跳过无法渲染的页面
        }

        final Uint8List imageBytes = pageImage.pixels;
        final String base64Image = 'data:image/png;base64,${base64Encode(imageBytes)}';

        content.add({
          'image_url': base64Image,
        });
        
      }
      

      if (content.length == 1) { // 只有提示，没有图片
        throw Exception('PDF 中没有可识别的图像');
      }

      return await llmProvider.chatWithContent(
        content: content,
        model: model,
      );
    } catch (e) {
      throw Exception('PDF 识别失败: $e');
    }
  }
}