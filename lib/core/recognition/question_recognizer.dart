

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

  static const String _classificationPrompt = """
你将看到一份多页 PDF 的图片，请按“大题”进行分类，并输出 JSON。
要求：
1.页码从 1 开始编号。
2.每一页必须且只能归入一个大题。
3.尽量把每一道大题分清楚。
4.只输出 JSON，不要附加任何说明或代码块格式。
5.题目名称尽量写成“第一大题：选择题/第二大题：填空题...”这类格式。
6.科目如果无法识别，请填写“未知”。
7.如果一道题目跨页，请把所有相关页码都列出来。（千万不要少）

输出格式示例（请严格遵循）：
{
  "groups": [
    {
      "index": 1,
      "title": "第一大题：选择题",
      "subject": "数学",
      "pages": [1, 2]
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

  Future<int> getPdfPageCount(String pdfPath) async {
    final PdfDocument pdfDocument = await PdfDocument.openFile(pdfPath);
    return pdfDocument.pages.length;
  }

  Future<String> classifyPdfQuestions(String pdfPath) async {
    final pageCount = await getPdfPageCount(pdfPath);
    final pages = List<int>.generate(pageCount, (i) => i + 1);
    final content = await _buildPdfContent(
      pdfPath: pdfPath,
      pages: pages,
      prompt: _classificationPrompt,
    );
    return await llmProvider.chatWithContent(
      content: content,
      model: model,
      isThinkingModel: isThinkingModel,
    );
  }

  Future<String> recognizeQuestionFromPdfPages({
    required String pdfPath,
    required List<int> pages,
    required String groupTitle,
    required String subject,
  }) async {
    final prompt = _buildGroupPrompt(groupTitle, subject);
    final content = await _buildPdfContent(
      pdfPath: pdfPath,
      pages: pages,
      prompt: prompt,
    );
    return await llmProvider.chatWithContent(
      content: content,
      model: model,
      isThinkingModel: isThinkingModel,
    );
  }

  Future<String> recognizeQuestionFromPdf(String pdfPath) async {
    try {
      final pageCount = await getPdfPageCount(pdfPath);
      final pages = List<int>.generate(pageCount, (i) => i + 1);
      final content = await _buildPdfContent(
        pdfPath: pdfPath,
        pages: pages,
        prompt: _prompt,
      );
      return await llmProvider.chatWithContent(
        content: content,
        model: model,
        isThinkingModel: isThinkingModel,
      );
    } catch (e) {
      throw Exception('PDF 识别失败: $e');
    }
  }

  String _buildGroupPrompt(String groupTitle, String subject) {
    final subjectText = subject.trim().isEmpty ? '未知' : subject.trim();
    return """
你将只识别以下大题的所有小题：
大题：$groupTitle
科目：$subjectText

请只输出该大题的小题，不要包含其他大题。
输出格式要求与之前一致，只输出 JSON，不要附加说明或代码块。

$_prompt
""";
  }

  Future<List<Map<String, dynamic>>> _buildPdfContent({
    required String pdfPath,
    required List<int> pages,
    required String prompt,
  }) async {
    final PdfDocument pdfDocument = await PdfDocument.openFile(pdfPath);
    final List<Map<String, dynamic>> content = [
      {'text': prompt},
    ];

    final pageSet = pages.where((p) => p > 0 && p <= pdfDocument.pages.length).toSet();
    final pageList = pageSet.toList()..sort();

    for (final pageNumber in pageList) {
      final PdfPage page = pdfDocument.pages[pageNumber - 1];
      final PdfImage? pageImage = await page.render(
        width: 1024,
      );

      if (pageImage == null) {
        continue;
      }

      final Uint8List imageBytes = pageImage.pixels;
      final img.Image image = img.Image.fromBytes(
        width: pageImage.width,
        height: pageImage.height,
        bytes: imageBytes.buffer,
        numChannels: 4,
      );
      final String base64Image = 'data:image/png;base64,${base64Encode(img.encodePng(image))}';

      content.add({
        'image_url': base64Image,
      });
    }

    if (content.length == 1) {
      throw Exception('PDF 中没有可识别的图像');
    }

    return content;
  }
}
