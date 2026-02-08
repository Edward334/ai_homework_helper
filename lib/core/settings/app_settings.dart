class AppSettings {
  final bool enableQuestionClassification;
  final int maxConcurrentTasks;

  const AppSettings({
    this.enableQuestionClassification = false,
    this.maxConcurrentTasks = 4,
  });

  AppSettings copyWith({
    bool? enableQuestionClassification,
    int? maxConcurrentTasks,
  }) {
    return AppSettings(
      enableQuestionClassification: enableQuestionClassification ?? this.enableQuestionClassification,
      maxConcurrentTasks: maxConcurrentTasks ?? this.maxConcurrentTasks,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final rawConcurrent = json['maxConcurrentTasks'];
    final parsedConcurrent = rawConcurrent is int ? rawConcurrent : int.tryParse('$rawConcurrent');
    return AppSettings(
      enableQuestionClassification: json['enableQuestionClassification'] ?? false,
      maxConcurrentTasks: (parsedConcurrent == null || parsedConcurrent <= 0) ? 4 : parsedConcurrent,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enableQuestionClassification': enableQuestionClassification,
      'maxConcurrentTasks': maxConcurrentTasks,
    };
  }
}
