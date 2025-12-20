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

  ChannelConfig({
    required this.name,
    required this.type,
    required this.apiUrl,
    required this.apiKey,
    required this.models,
    required this.selectedModel,
    this.isDefault = false,
  });
}
