import 'dart:convert';
import 'dart:io';

import '../models/chat_message.dart';

/// Calls the Gemini API directly from the app, streaming the reply.
///
/// Talks to the REST API itself rather than through the old
/// google_generative_ai package, which can't turn down Gemini's
/// "thinking" -- the main reason replies took 15-20 s. With thinking at
/// [_thinking] and the reply streamed, the first words arrive in about a
/// second, like the Gemini app.
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
  static const _model = 'gemini-3.6-flash';

  /// "minimal" answers everyday questions fast; Gemini still reasons a
  /// little when a question needs it.
  static const _thinking = 'minimal';

  /// The reply to [message], in pieces as Gemini writes it.
  /// [context] goes in as instructions: who the family is and what's in
  /// their app right now.
  Stream<String> ask(
    String message,
    List<ChatMessage> history, {
    String context = '',
  }) async* {
    if (_apiKey.isEmpty) {
      throw StateError(
        'No Gemini API key configured -- run with '
        '--dart-define-from-file=dart_define.json (see dart_define.example.json).',
      );
    }
    final body = jsonEncode({
      if (context.isNotEmpty)
        'systemInstruction': {
          'parts': [
            {'text': context},
          ],
        },
      'contents': [
        for (final turn in history)
          {
            'role': turn.role == ChatRole.model ? 'model' : 'user',
            'parts': [
              {'text': turn.text},
            ],
          },
        {
          'role': 'user',
          'parts': [
            {'text': message},
          ],
        },
      ],
      'generationConfig': {
        'thinkingConfig': {'thinkingLevel': _thinking},
      },
    });

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.postUrl(
        Uri.https(
          'generativelanguage.googleapis.com',
          '/v1beta/models/$_model:streamGenerateContent',
          {'alt': 'sse'},
        ),
      );
      request.headers
        ..set('x-goog-api-key', _apiKey)
        ..contentType = ContentType.json;
      request.add(utf8.encode(body));
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      if (response.statusCode != 200) {
        final error = await response.transform(utf8.decoder).join();
        throw StateError(_errorMessage(response.statusCode, error));
      }
      // Server-sent events: one `data: {...}` line per chunk of reply.
      await for (final line
          in response
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .timeout(const Duration(seconds: 30))) {
        if (!line.startsWith('data:')) continue;
        final chunk = jsonDecode(line.substring(5));
        final parts =
            (chunk['candidates'] as List?)?.firstOrNull?['content']?['parts']
                as List?;
        for (final part in parts ?? const []) {
          // Skip the model's thought summaries; only the answer is shown.
          if (part['thought'] == true) continue;
          final text = part['text'];
          if (text is String && text.isNotEmpty) yield text;
        }
      }
    } finally {
      client.close(force: true);
    }
  }

  static String _errorMessage(int status, String body) {
    try {
      final message = jsonDecode(body)['error']['message'];
      if (message is String) return 'Gemini said ($status): $message';
    } on Object {
      // Not JSON; fall through.
    }
    return 'Gemini request failed ($status).';
  }
}
