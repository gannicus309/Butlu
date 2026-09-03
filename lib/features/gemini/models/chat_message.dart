enum ChatRole { user, model }

class ChatMessage {
  final ChatRole role;
  final String text;

  const ChatMessage({required this.role, required this.text});
}
