import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/gemini_chat_service.dart';

final geminiChatServiceProvider = Provider<GeminiChatService>(
  (ref) => GeminiChatService(),
);
