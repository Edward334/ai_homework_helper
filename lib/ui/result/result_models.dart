enum QuestionStatus {
  loading,
  done,
  error,
}

class QuestionItem {
  final String title;
  QuestionStatus status;
  String answer;
  String explanation;

  QuestionItem({
    required this.title,
    this.status = QuestionStatus.loading,
    this.answer = '',
    this.explanation = '',
  });
}

class QuestionGroup {
  final String title;
  final String subject;
  final List<int> pages;
  final List<QuestionItem> questions;

  QuestionGroup({
    required this.title,
    required this.subject,
    required this.pages,
    required this.questions,
  });

  String get displayTitle {
    if (subject.trim().isEmpty) return title;
    return '$title · $subject';
  }
}
