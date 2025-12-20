import '../../ui/settings/models.dart';
import 'llm_provider.dart';
import 'openai_provider.dart';
import 'gemini_provider.dart';

class LLMClient {
  static LLMProvider fromChannel(ChannelConfig channel) {
    switch (channel.type) {
      case ChannelType.openai:
        return OpenAIProvider(
          apiUrl: channel.apiUrl,
          apiKey: channel.apiKey,
        );
      case ChannelType.gemini:
        return GeminiProvider(
          apiKey: channel.apiKey,
        );
    }
  }
}