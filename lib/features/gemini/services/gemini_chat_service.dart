import '../../../services/gemini_client.dart';
import '../models/chat_message.dart';
import 'gemini_actions.dart';

/// Ask Gemini: a conversation that knows the family's data and can
/// propose changes to it (see [kGeminiFunctions]).
///
/// Streams the reply with thinking turned down, so the first words arrive
/// in about a second, and lets Gemini search Google for things it can't
/// know (trends, prices, opening hours).
class GeminiChatService {
  GeminiChatService({GeminiClient? client})
    : _client = client ?? GeminiClient();

  final GeminiClient _client;

  static const _howToAct = '''

ACTIONS: You can propose changes in Butlu with the functions you have --
shopping list, chores, meal plan, inventory. Propose them whenever they
would help (e.g. the missing ingredients of a recipe, a chore the user
mentions). They are NOT carried out until the user taps "Do it" on each,
so never say you've done something; say you've suggested it. Use Google
Search only for things that change over time -- current trends, new
products, prices, news, opening hours. Don't search for recipes or cooking
advice; you know those already.''';

  /// The reply to [message], piece by piece.
  /// [context] is the family snapshot from buildFamilyContext.
  Stream<GeminiEvent> ask(
    String message,
    List<ChatMessage> history, {
    String context = '',
  }) => _client.stream(
    system: context + _howToAct,
    contents: [
      for (final turn in history)
        if (turn.historyText.isNotEmpty)
          {
            'role': turn.role == ChatRole.model ? 'model' : 'user',
            'parts': [
              {'text': turn.historyText},
            ],
          },
      {
        'role': 'user',
        'parts': [
          {'text': message},
        ],
      },
    ],
    functions: kGeminiFunctions,
    search: true,
  );
}
