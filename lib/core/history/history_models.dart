class HistoryQuestion {
  final String question;
  final String answer;
  final String explanation;

  HistoryQuestion({
    required this.question,
    required this.answer,
    required this.explanation,
  });

  factory HistoryQuestion.fromJson(Map<String, dynamic> json) {
    return HistoryQuestion(
      question: json['question'] ?? '',
      answer: json['answer'] ?? '',
      explanation: json['explanation'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'answer': answer,
      'explanation': explanation,
    };
  }
}

class HistoryRecord {
  final String id;
  final DateTime createdAt;
  final String sourceName;
  final String sourcePath;
  final List<HistoryQuestion> questions;

  HistoryRecord({
    required this.id,
    required this.createdAt,
    required this.sourceName,
    required this.sourcePath,
    required this.questions,
  });

  factory HistoryRecord.fromJson(Map<String, dynamic> json) {
    final List<dynamic> list = json['questions'] ?? [];
    return HistoryRecord(
      id: json['id'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      sourceName: json['sourceName'] ?? '',
      sourcePath: json['sourcePath'] ?? '',
      questions: list.map((q) => HistoryQuestion.fromJson(q as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'sourceName': sourceName,
      'sourcePath': sourcePath,
      'questions': questions.map((q) => q.toJson()).toList(),
    };
  }
}
