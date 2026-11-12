import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bills/providers/bill_providers.dart';
import '../../calendar/providers/calendar_providers.dart';
import '../../chores/providers/chore_providers.dart';
import '../../family_notes/providers/family_notes_providers.dart';
import '../../grocery/providers/grocery_providers.dart';
import '../../inventory/providers/inventory_providers.dart';
import '../../meals/providers/meal_plan_providers.dart';
import '../models/chat_message.dart';
import '../providers/gemini_providers.dart';
import '../services/family_context.dart';

class GeminiChatScreen extends ConsumerStatefulWidget {
  const GeminiChatScreen({super.key});

  @override
  ConsumerState<GeminiChatScreen> createState() => _GeminiChatScreenState();
}

class _GeminiChatScreenState extends ConsumerState<GeminiChatScreen> {
  final _messages = <ChatMessage>[];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  /// The reply so far while Gemini is still writing it.
  String? _streaming;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(ChatMessage(role: ChatRole.user, text: text));
      _sending = true;
      _inputController.clear();
    });
    _scrollToBottom();

    try {
      final history = _messages.sublist(0, _messages.length - 1);
      final context = await buildFamilyContext(ref);
      final buffer = StringBuffer();
      setState(() => _streaming = '');
      await for (final piece
          in ref
              .read(geminiChatServiceProvider)
              .ask(text, history, context: context)) {
        buffer.write(piece);
        if (!mounted) return;
        setState(() => _streaming = buffer.toString());
        _scrollToBottom();
      }
      if (!mounted) return;
      setState(
        () => _messages.add(
          ChatMessage(
            role: ChatRole.model,
            text: buffer.isEmpty ? '(No answer came back.)' : '$buffer',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _messages.add(
          ChatMessage(
            role: ChatRole.model,
            text: "Sorry, that didn't work: $e",
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _streaming = null;
        });
      }
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kept loaded while the chat is open, so each question's snapshot of
    // the family's data is instant.
    ref
      ..watch(inventoryProvider)
      ..watch(shoppingListProvider)
      ..watch(choresProvider)
      ..watch(eventsProvider)
      ..watch(weekMealPlanProvider)
      ..watch(billsProvider)
      ..watch(familyNotesProvider);
    final streaming = _streaming;
    return Scaffold(
      appBar: AppBar(title: const Text('Ask Gemini')),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Ask about what to cook, plans for the week, '
                        'anything.\n\nGemini sees your inventory, shopping '
                        'list, chores, family notes, the next two weeks of '
                        'calendar, meal plan and bills -- never the Vault.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (streaming == null ? 0 : 1),
                    itemBuilder: (context, index) => index < _messages.length
                        ? _bubble(context, _messages[index])
                        : _bubble(
                            context,
                            ChatMessage(
                              role: ChatRole.model,
                              text: streaming!.isEmpty ? '…' : streaming,
                            ),
                          ),
                  ),
          ),
          if (_sending && streaming == null)
            const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration: const InputDecoration(
                        hintText: 'Message Gemini',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sending ? null : _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(BuildContext context, ChatMessage message) {
    final isUser = message.role == ChatRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: isUser
            ? Text(message.text)
            : SelectableText.rich(
                _markdown(message.text, DefaultTextStyle.of(context).style),
              ),
      ),
    );
  }

  /// Gemini's light markdown: **bold**, *italic*, `- ` bullets, # headings.
  static TextSpan _markdown(String text, TextStyle base) {
    final spans = <InlineSpan>[];
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      var style = base;
      final heading = RegExp(r'^\s*#{1,6}\s+').firstMatch(line);
      if (heading != null) {
        line = line.substring(heading.end);
        style = base.copyWith(fontWeight: FontWeight.w700);
      }
      final bullet = RegExp(r'^(\s*)[-*•]\s+').firstMatch(line);
      if (bullet != null) {
        line = '${bullet[1]}•  ${line.substring(bullet.end)}';
      }
      final inline = RegExp(
        r'\*\*(.+?)\*\*|(?<![*\w])[*_](?!\s)(.+?)(?<!\s)[*_](?![*\w])',
      );
      var at = 0;
      for (final m in inline.allMatches(line)) {
        if (m.start > at) {
          spans.add(TextSpan(text: line.substring(at, m.start), style: style));
        }
        spans.add(
          m[1] != null
              ? TextSpan(
                  text: m[1],
                  style: style.copyWith(fontWeight: FontWeight.w700),
                )
              : TextSpan(
                  text: m[2],
                  style: style.copyWith(fontStyle: FontStyle.italic),
                ),
        );
        at = m.end;
      }
      if (at < line.length) {
        spans.add(TextSpan(text: line.substring(at), style: style));
      }
      if (i < lines.length - 1) spans.add(TextSpan(text: '\n', style: base));
    }
    return TextSpan(children: spans);
  }
}
