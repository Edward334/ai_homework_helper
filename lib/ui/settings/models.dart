enum ChannelType {
  openai,
  gemini,
}

class ChannelConfig {
  String name;
  ChannelType type;
  String apiUrl;
  String apiKey;
  List<String> models;
  String selectedModel;
  bool isDefault;
  bool isThinkingModel;

  ChannelConfig({
    required this.name,
    required this.type,
    required this.apiUrl,
    required this.apiKey,
    required this.models,
    required this.selectedModel,
    this.isDefault = false,
    this.isThinkingModel = false,
  });

  // ===== JSON =====
  factory ChannelConfig.fromJson(Map<String, dynamic> json) {
    return ChannelConfig(
      name: json['name'],
      type: ChannelType.values.firstWhere(
        (e) => e.name == json['type'],
      ),
      apiUrl: json['apiUrl'],
      apiKey: json['apiKey'],
      models: List<String>.from(json['models']),
      selectedModel: json['selectedModel'],
      isDefault: json['isDefault'] ?? false,
      isThinkingModel: json['isThinkingModel'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type.name,
      'apiUrl': apiUrl,
      'apiKey': apiKey,
      'models': models,
      'selectedModel': selectedModel,
      'isDefault': isDefault,
      'isThinkingModel': isThinkingModel,
    };
  }
}
