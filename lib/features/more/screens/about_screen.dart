import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/butlu_logo.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/family_members_provider.dart';

/// Stamped in by tool/deploy.sh and tool/resign.sh; empty in `flutter run`.
const _commit = String.fromEnvironment('BUTLU_COMMIT');
const _builtAt = String.fromEnvironment('BUTLU_BUILT_AT');
const _hasGemini = String.fromEnvironment('GEMINI_API_KEY') != '';

/// Version, build and signing details reported by iOS.
final appInfoProvider = FutureProvider<Map<String, Object?>>((ref) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return const {};
  try {
    final info = await const MethodChannel('butlu/signing')
        .invokeMapMethod<String, Object?>('appInfo');
    return info ?? const {};
  } on Object {
    return const {};
  }
});

/// More → About: which build this is and what it's connected to.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final info = ref.watch(appInfoProvider).value ?? const {};
    final user = ref.watch(authStateProvider).value;
    final family = ref.watch(familyDocProvider).value ?? const {};
    final members = ref.watch(familyMembersProvider).value ?? const {};
    final version = info['version'] ?? '…';
    final build = info['build'] ?? '…';

    final expiresRaw = info['expiresAt'];
    final expires = expiresRaw is String
        ? DateTime.tryParse(expiresRaw)?.toLocal()
        : null;
    String expiryText() {
      if (expires == null) {
        return info.isEmpty ? '…' : 'Never (App Store build)';
      }
      final left = expires.difference(DateTime.now());
      final when = DateFormat('EEE d MMM, HH:mm').format(expires);
      if (left.isNegative) return '$when (expired)';
      final days = left.inDays;
      return '$when · '
          '${days >= 1 ? '$days day${days == 1 ? '' : 's'}' : '${left.inHours} h'} left';
    }

    final built = DateTime.tryParse(_builtAt)?.toLocal();

    Widget row(String label, String value, {bool copy = false}) => ListTile(
      dense: true,
      title: Text(label),
      trailing: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.58,
        ),
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      onLongPress: copy
          ? () {
              Clipboard.setData(ClipboardData(text: value));
              HapticFeedback.selectionClick();
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(persist: false, content: Text('Copied $label')),
                );
            }
          : null,
    );

    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          const Center(child: ButluLogo(size: 72)),
          const SizedBox(height: 10),
          Center(child: Text('Butlu', style: theme.textTheme.headlineSmall)),
          Center(
            child: Text(
              'Version $version ($build)',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'The family organiser',
              style: theme.textTheme.bodySmall,
            ),
          ),
          section('This build'),
          row('Version', '$version', copy: true),
          row('Build number', '$build'),
          row(
            'Commit',
            _commit.isEmpty ? 'Development run' : _commit,
            copy: true,
          ),
          if (built != null)
            row('Built', DateFormat('EEE d MMM yyyy, HH:mm').format(built)),
          row('Works until', expiryText()),
          section('Connected to'),
          row('Signed in as', user?.email ?? user?.displayName ?? '—'),
          row('Family', '${family['name'] ?? '—'}'),
          row('Members', members.isEmpty ? '—' : members.values.join(', ')),
          row('Firebase project', Firebase.app().options.projectId),
          row('Gemini', _hasGemini ? 'On' : 'Off (no key in this build)'),
          section('Device'),
          row('Phone', '${info['device'] ?? '—'}'),
          row('iOS', '${info['iosVersion'] ?? '—'}'),
          row('Bundle ID', '${info['bundleId'] ?? '—'}'),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Open-source licences'),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Butlu',
              applicationVersion: '$version ($build)',
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
