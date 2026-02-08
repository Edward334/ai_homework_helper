import 'dart:convert';

import 'result_models.dart';

class AiJsonHelper {
  static List<QuestionItem> parseQuestions(String raw) {
    final data = _decodeObject(raw);
    final List<dynamic> questionList = data['questions'] ?? [];
    return questionList.map((item) {
      final map = item is Map<String, dynamic> ? item : <String, dynamic>{};
      return QuestionItem(
        title: map['question'] ?? '未知题目',
        answer: map['answer'] ?? '暂无答案',
        explanation: map['explanation'] ?? '暂无解析',
        status: QuestionStatus.done,
      );
    }).toList();
  }

  static Map<String, dynamic> decodeObject(String raw) {
    return _decodeObject(raw);
  }

  static Map<String, dynamic> _decodeObject(String raw) {
    String sanitized = _sanitizeAiJson(raw);
    sanitized = _extractJsonPayload(sanitized);
    sanitized = _escapeNewlinesInJsonStrings(sanitized);
    sanitized = _stripTrailingCommas(sanitized);
    try {
      return jsonDecode(sanitized) as Map<String, dynamic>;
    } catch (_) {
      final repaired = _repairUnescapedQuotesInJsonStrings(sanitized);
      return jsonDecode(repaired) as Map<String, dynamic>;
    }
  }

  static String _sanitizeAiJson(String raw) {
    final trimmed = raw.trim();
    final fenceMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```', caseSensitive: false)
        .firstMatch(trimmed);
    if (fenceMatch != null && fenceMatch.groupCount >= 1) {
      return fenceMatch.group(1)!.trim();
    }
    return trimmed;
  }

  static String _extractJsonPayload(String input) {
    final startObj = input.indexOf('{');
    final startArr = input.indexOf('[');
    int start;
    if (startObj == -1 && startArr == -1) return input;
    if (startObj == -1) {
      start = startArr;
    } else if (startArr == -1) {
      start = startObj;
    } else {
      start = startObj < startArr ? startObj : startArr;
    }

    int depth = 0;
    bool inString = false;
    bool escape = false;
    for (int i = start; i < input.length; i++) {
      final ch = input[i];
      if (escape) {
        escape = false;
        continue;
      }
      if (ch == '\\') {
        if (inString) {
          escape = true;
        }
        continue;
      }
      if (ch == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;

      if (ch == '{' || ch == '[') depth++;
      if (ch == '}' || ch == ']') {
        depth--;
        if (depth == 0) {
          return input.substring(start, i + 1);
        }
      }
    }
    return input;
  }

  static String _escapeNewlinesInJsonStrings(String input) {
    final buffer = StringBuffer();
    bool inString = false;
    bool escape = false;
    for (int i = 0; i < input.length; i++) {
      final ch = input[i];
      if (escape) {
        buffer.write(ch);
        escape = false;
        continue;
      }
      if (ch == '\\') {
        buffer.write(ch);
        if (inString) escape = true;
        continue;
      }
      if (ch == '"') {
        inString = !inString;
        buffer.write(ch);
        continue;
      }
      if (inString && (ch == '\n' || ch == '\r')) {
        if (ch == '\r' && i + 1 < input.length && input[i + 1] == '\n') {
          i++;
        }
        buffer.write('\\n');
        continue;
      }
      buffer.write(ch);
    }
    return buffer.toString();
  }

  static String _stripTrailingCommas(String input) {
    return input.replaceAll(RegExp(r',\s*(\}|\])'), r'$1');
  }

  static String _repairUnescapedQuotesInJsonStrings(String input) {
    final buffer = StringBuffer();
    bool inString = false;
    bool escape = false;

    int i = 0;
    while (i < input.length) {
      final ch = input[i];

      if (escape) {
        buffer.write(ch);
        escape = false;
        i++;
        continue;
      }

      if (ch == '\\') {
        buffer.write(ch);
        if (inString) {
          escape = true;
        }
        i++;
        continue;
      }

      if (ch == '"') {
        if (!inString) {
          inString = true;
          buffer.write(ch);
          i++;
          continue;
        }

        int j = i + 1;
        while (j < input.length &&
            (input[j] == ' ' || input[j] == '\t' || input[j] == '\r' || input[j] == '\n')) {
          j++;
        }
        if (j >= input.length || input[j] == ',' || input[j] == '}' || input[j] == ']') {
          inString = false;
          buffer.write(ch);
        } else {
          buffer.write(r'\"');
        }
        i++;
        continue;
      }

      if (inString && (ch == '\n' || ch == '\r')) {
        if (ch == '\r' && i + 1 < input.length && input[i + 1] == '\n') {
          i++;
        }
        buffer.write(r'\n');
        i++;
        continue;
      }

      buffer.write(ch);
      i++;
    }

    if (inString) {
      buffer.write('"');
    }

    return buffer.toString();
  }
}
