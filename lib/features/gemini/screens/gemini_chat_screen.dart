import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/gemini_client.dart';
import '../../bills/providers/bill_providers.dart';
import '../../calendar/providers/calendar_providers.dart';
import '../../chores/providers/chore_providers.dart';
import '../../family_notes/providers/family_notes_providers.dart';
import '../../grocery/providers/grocery_providers.dart';
import '../../inventory/providers/inventory_providers.dart';
import '../../meals/providers/meal_plan_providers.dart';
import '../models/chat_message.dart';
import '../models/gemini_prompts.dart';
import '../providers/gemini_providers.dart';
import '../services/family_context.dart';
import '../services/gemini_actions.dart';

/// Ask Gemini: chat about the family's data, with ready-made questions and
/// actions Gemini can propose (shown as cards; nothing happens until
/// someone taps "Do it").
class GeminiChatScreen extends ConsumerStatefulWidget {
  const GeminiChatScreen({super.key, this.initialPrompt});

  /// Asked straight away, e.g. from a button elsewhere in the app.
  final String? initialPrompt;

  @override
  ConsumerState<GeminiChatScreen> createState() => _GeminiChatScreenState();
}

class _GeminiChatScreenState extends ConsumerState<GeminiChatScreen> {
  final _messages = <ChatMessage>[];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  /// The reply while Gemini is still writing it.
  String? _streaming;
  final _streamingActions = <ProposedAction>[];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    final q = widget.initialPrompt;
    if (q != null && q.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _send(q));
    }
  }

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

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _inputController.text).trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(ChatMessage(role: ChatRole.user, text: text));
      _sending = true;
      _inputController.clear();
    });
    _scrollToBottom();

    final buffer = StringBuffer();
    var searched = false;
    try {
      final history = _messages.sublist(0, _messages.length - 1);
      final context = await buildFamilyContext(ref);
      setState(() => _streaming = '');
      await for (final event
          in ref
              .read(geminiChatServiceProvider)
              .ask(text, history, context: context)) {
        if (!mounted) return;
        switch (event) {
          case GeminiText(:final text):
            buffer.write(text);
            _searching = false;
          case GeminiCall(:final name, :final args):
            _streamingActions.add(ProposedAction(name, args));
          case GeminiSearched():
            searched = true;
            _searching = true;
        }
        setState(() => _streaming = buffer.toString());
        _scrollToBottom();
      }
      if (!mounted) return;
      setState(
        () => _messages.add(
          ChatMessage(
            role: ChatRole.model,
            text: buffer.isEmpty && _streamingActions.isEmpty
                ? '(No answer came back.)'
                : '$buffer'.trim(),
            actions: [..._streamingActions],
            searched: searched,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _messages.add(
          ChatMessage(
            role: ChatRole.model,
            text: [
              if (buffer.isNotEmpty) '$buffer',
              "Sorry, that didn't work: $e",
            ].join('\n\n'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _streaming = null;
          _searching = false;
          _streamingActions.clear();
        });
      }
      _scrollToBottom();
    }
  }

  Future<void> _run(ProposedAction action) async {
    HapticFeedback.mediumImpact();
    try {
      final outcome = await runGeminiAction(ref, action);
      setState(() {
        action.state = ActionState.done;
        action.outcome = outcome;
      });
    } catch (e) {
      setState(() {
        action.state = ActionState.failed;
        action.outcome = '$e'.replaceFirst('Bad state: ', '');
      });
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, size: 20),
            SizedBox(width: 8),
            Text('Ask Gemini'),
          ],
        ),
        actions: [
          if (_messages.isNotEmpty && !_sending)
            IconButton(
              tooltip: 'New chat',
              icon: const Icon(Icons.add_comment_outlined),
              onPressed: () => setState(_messages.clear),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Gemini sees your inventory, shopping list, chores, '
                        'family notes, the next two weeks of calendar, meal '
                        'plan and bills -- never the Vault. It can suggest '
                        'changes; you tap Do it.',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      for (final p in kGeminiPrompts)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Text(
                              p.emoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                            title: Text(p.label),
                            trailing: const Icon(Icons.arrow_upward, size: 18),
                            onTap: () => _send(p.prompt),
                          ),
                        ),
                    ],
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
                              text: streaming!.isEmpty
                                  ? (_searching ? 'Searching Google…' : '…')
                                  : streaming,
                              actions: _streamingActions,
                            ),
                            live: true,
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
          if (_messages.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  for (final p in kGeminiPrompts)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        avatar: Text(p.emoji),
                        label: Text(p.label),
                        onPressed: _sending ? null : () => _send(p.prompt),
                      ),
                    ),
                ],
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
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 4,
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

  Widget _bubble(
    BuildContext context,
    ChatMessage message, {
    bool live = false,
  }) {
    final theme = Theme.of(context);
    final isUser = message.role == ChatRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * (isUser ? 0.75 : 0.88),
        ),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (message.text.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isUser
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: isUser
                    ? Text(message.text)
                    : SelectableText.rich(
                        _markdown(
                          message.text,
                          DefaultTextStyle.of(context).style,
                        ),
                      ),
              ),
            if (message.searched)
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 2),
                child: Text(
                  '🔎 Searched Google',
                  style: theme.textTheme.labelSmall,
                ),
              ),
            for (final a in message.actions) _actionCard(context, a, live),
            if (!live &&
                message.actions
                        .where((a) => a.state == ActionState.pending)
                        .length >
                    1)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 6),
                child: FilledButton.tonalIcon(
                  onPressed: () async {
                    for (final a in [...message.actions]) {
                      if (a.state == ActionState.pending) await _run(a);
                    }
                  },
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Do all'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _actionCard(BuildContext context, ProposedAction a, bool live) {
    final theme = Theme.of(context);
    final (status, color) = switch (a.state) {
      ActionState.pending => (null, theme.colorScheme.primary),
      ActionState.done => ('✓ ${a.outcome ?? 'Done'}', const Color(0xFF199E70)),
      ActionState.skipped => ('Skipped', theme.colorScheme.onSurfaceVariant),
      ActionState.failed => (
        "Couldn't: ${a.outcome ?? 'unknown error'}",
        theme.colorScheme.error,
      ),
    };
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(a.icon, size: 20, color: color),
                const SizedBox(width: 10),
                Expanded(child: Text(a.summary)),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: status != null
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(0, 6, 4, 4),
                      child: Text(
                        status,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: color,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: live
                              ? null
                              : () => setState(
                                  () => a.state = ActionState.skipped,
                                ),
                          child: const Text('Skip'),
                        ),
                        FilledButton(
                          onPressed: live ? null : () => _run(a),
                          child: const Text('Do it'),
                        ),
                      ],
                    ),
            ),
          ],
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
