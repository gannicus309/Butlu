import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// One piece of a streamed Gemini reply.
sealed class GeminiEvent {}

/// More of the answer's text.
class GeminiText extends GeminiEvent {
  GeminiText(this.text);
  final String text;
}

/// Gemini wants Butlu to do something (a declared function).
class GeminiCall extends GeminiEvent {
  GeminiCall(this.name, this.args);
  final String name;
  final Map<String, dynamic> args;
}

/// Gemini searched the web (for trends, prices, news).
class GeminiSearched extends GeminiEvent {
  GeminiSearched(this.queries);
  final List<String> queries;
}

/// Butlu's one way of talking to Gemini: the REST API directly, so it can
/// stream replies, turn thinking down, and declare actions -- none of
/// which the old google_generative_ai package could do.
///
/// The key is a build-time `--dart-define` (see dart_define.example.json);
/// it's billed to the Google Cloud project it was created in.
class GeminiClient {
  GeminiClient({String? apiKey})
    : _apiKey = apiKey ?? const String.fromEnvironment('GEMINI_API_KEY');

  final String _apiKey;
  static const model = 'gemini-3.6-flash';

  bool get hasKey => _apiKey.isNotEmpty;

  /// Streams a reply to [contents] (Gemini's `{role, parts}` turns).
  /// [functions] are actions Gemini may propose; [search] lets it look
  /// things up on Google.
  Stream<GeminiEvent> stream({
    required List<Map<String, Object?>> contents,
    String system = '',
    List<Map<String, Object?>> functions = const [],
    bool search = false,
    String thinking = 'minimal',
  }) async* {
    final client = _client();
    try {
      final response = await _post(
        client,
        'streamGenerateContent',
        {'alt': 'sse'},
        {
          if (system.isNotEmpty)
            'systemInstruction': {
              'parts': [
                {'text': system},
              ],
            },
          'contents': contents,
          if (functions.isNotEmpty || search)
            'tools': [
              if (functions.isNotEmpty) {'functionDeclarations': functions},
              if (search) {'googleSearch': <String, Object?>{}},
            ],
          if (functions.isNotEmpty && search)
            'toolConfig': {'includeServerSideToolInvocations': true},
          'generationConfig': {
            'thinkingConfig': {'thinkingLevel': thinking},
          },
        },
      );
      // Server-sent events: one `data: {...}` line per chunk.
      await for (final line
          in response
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .timeout(const Duration(seconds: 45))) {
        if (!line.startsWith('data:')) continue;
        final chunk = jsonDecode(line.substring(5));
        final parts =
            (chunk['candidates'] as List?)?.firstOrNull?['content']?['parts']
                as List?;
        for (final part in parts ?? const []) {
          if (part is! Map || part['thought'] == true) continue;
          final call = part['functionCall'];
          final tool = part['toolCall'];
          final text = part['text'];
          if (call is Map) {
            yield GeminiCall(
              '${call['name']}',
              Map<String, dynamic>.from(call['args'] as Map? ?? const {}),
            );
          } else if (tool is Map) {
            final queries = (tool['args'] as Map?)?['queries'];
            yield GeminiSearched([
              for (final q in queries as List? ?? const []) '$q',
            ]);
          } else if (text is String && text.isNotEmpty) {
            yield GeminiText(text);
          }
        }
      }
    } finally {
      client.close(force: true);
    }
  }

  /// A one-off JSON answer to [prompt], optionally about a photo.
  Future<Map<String, dynamic>?> json(
    String prompt, {
    Uint8List? jpeg,
    String thinking = 'low',
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final client = _client();
    try {
      final response = await _post(client, 'generateContent', null, {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': prompt},
              if (jpeg != null)
                {
                  'inlineData': {
                    'mimeType': 'image/jpeg',
                    'data': base64Encode(jpeg),
                  },
                },
            ],
          },
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
          'temperature': 0,
          'thinkingConfig': {'thinkingLevel': thinking},
        },
      }).timeout(timeout);
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);
      final parts =
          (jsonDecode(body)['candidates'] as List?)
                  ?.firstOrNull?['content']?['parts']
              as List?;
      final text = [
        for (final p in parts ?? const [])
          if (p is Map && p['thought'] != true && p['text'] is String)
            p['text'] as String,
      ].join();
      final decoded = jsonDecode(text);
      return decoded is Map<String, dynamic> ? decoded : null;
    } finally {
      client.close(force: true);
    }
  }

  HttpClient _client() =>
      HttpClient()..connectionTimeout = const Duration(seconds: 10);

  Future<HttpClientResponse> _post(
    HttpClient client,
    String method,
    Map<String, String>? query,
    Map<String, Object?> body,
  ) async {
    if (!hasKey) {
      throw StateError(
        'No Gemini API key in this build -- see dart_define.example.json.',
      );
    }
    final request = await client.postUrl(
      Uri.https(
        'generativelanguage.googleapis.com',
        '/v1beta/models/$model:$method',
        query,
      ),
    );
    request.headers
      ..set('x-goog-api-key', _apiKey)
      ..contentType = ContentType.json;
    request.add(utf8.encode(jsonEncode(body)));
    final response = await request.close().timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      final error = await response.transform(utf8.decoder).join();
      String message = 'Gemini request failed (${response.statusCode}).';
      try {
        final m = jsonDecode(error)['error']['message'];
        if (m is String) message = 'Gemini said (${response.statusCode}): $m';
      } on Object {
        // Not JSON.
      }
      throw StateError(message);
    }
    return response;
  }
}
