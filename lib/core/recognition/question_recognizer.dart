

import 'dart:convert';
import 'dart:typed_data';

import 'package:ai_homework_helper/core/llm/llm_provider.dart';
import 'package:ai_homework_helper/core/recognition/image_to_base64.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:image/image.dart' as img;

class QuestionRecognizer {
  final LLMProvider llmProvider;
  final String model;
  final bool isThinkingModel;

  QuestionRecognizer({required this.llmProvider, required this.model, this.isThinkingModel = false});

  static const String _prompt = """
请识别图片中的题目，并以以下 JSON 格式输出题目、答案和解析。
如果图片中包含多个题目，请将它们都识别出来。
如果无法识别，请返回一个空的题目列表。
请直接输出 JSON，不要包含任何额外的文字或解释以及不要使用代码的格式，严格按照下面的格式输出。（也不要包含'''或```之类的符号，直接用{}按格式输出）
题目、答案、解析中的换行请用空格连接，不要在字符串中输出真实换行符。

以下是一个输出实例，请你严格按照以下形式输出，不要使用'''或```之类的符号，解析请使用中文：
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
      isThinkingModel: isThinkingModel,
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
        final img.Image? image = img.Image.fromBytes(
          width: pageImage.width,
          height: pageImage.height,
          bytes: imageBytes.buffer,
          numChannels: 4, // Assuming the pixel format is RGBA (4 channels)
        );
        if (image == null) {
          continue; // Skip if image creation fails
        }
        final String base64Image = 'data:image/png;base64,${base64Encode(img.encodePng(image))}';

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
        isThinkingModel: isThinkingModel,
      );
    } catch (e) {
      throw Exception('PDF 识别失败: $e');
    }
  }
}
