import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/chat_message.dart';

/// Calls the Gemini API directly from the app.
///
/// The API key is a build-time `--dart-define`, not a hardcoded constant --
/// see `dart_define.example.json`. Butlu's GitHub repo is public, so unlike
/// the Firebase/Google-Sign-In web client ID (a public OAuth identifier,
/// safe to commit), an API key committed to source would be visible to
/// literally anyone, not just extractable from a compiled build. Keeping it
/// out of git is the point; it isn't secret from anyone with the compiled
/// app in hand, which is the accepted trade-off for a private 2-person app
/// calling the API directly instead of through a paid backend proxy.
class GeminiChatService {
  GeminiChatService({String? apiKey})
    : _apiKey = apiKey ?? const String.fromEnvironment('GEMINI_API_KEY');

  final String _apiKey;
  static const _modelName = 'gemini-3.6-flash';

  Future<String> ask(String message, List<ChatMessage> history) async {
    if (_apiKey.isEmpty) {
      throw StateError(
        'No Gemini API key configured -- run with '
        '--dart-define-from-file=dart_define.json (see dart_define.example.json).',
      );
    }

    final model = GenerativeModel(model: _modelName, apiKey: _apiKey);
    final chat = model.startChat(
      history: [
        for (final turn in history)
          turn.role == ChatRole.model
              ? Content.model([TextPart(turn.text)])
              : Content.text(turn.text),
      ],
    );

    final response = await chat.sendMessage(Content.text(message));
    return response.text ?? "Gemini didn't return a response.";
  }
}
