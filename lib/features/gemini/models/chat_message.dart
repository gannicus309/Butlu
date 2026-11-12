import '../services/gemini_actions.dart';

enum ChatRole { user, model }

class ChatMessage {
  ChatMessage({
    required this.role,
    required this.text,
    List<ProposedAction>? actions,
    this.searched = false,
  }) : actions = actions ?? [];

  final ChatRole role;
  final String text;

  /// Things Gemini offered to do, shown as cards under its reply.
  final List<ProposedAction> actions;

  /// Whether Gemini looked things up on Google for this reply.
  final bool searched;

  /// The text Gemini sees again in later turns, including what became of
  /// its proposals.
  String get historyText => [
    if (text.isNotEmpty) text,
    for (final a in actions) a.historyNote,
  ].join('\n');
}
