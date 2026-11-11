import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';

/// Shown after sign-in when the user isn't a family member yet -- either
/// they have a pending invite to accept, or they need to create the family
/// and invite their spouse by email.
class FamilySetupScreen extends ConsumerStatefulWidget {
  const FamilySetupScreen({super.key, required this.status});

  final FamilyStatus status;

  @override
  ConsumerState<FamilySetupScreen> createState() => _FamilySetupScreenState();
}

class _FamilySetupScreenState extends ConsumerState<FamilySetupScreen> {
  final _spouseEmailController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _spouseEmailController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      ref.invalidate(familyStatusProvider);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createFamily() async {
    final user = ref.read(authStateProvider).value;
    if (user == null || user.email == null) return;
    final spouseEmail = _spouseEmailController.text.trim();
    if (spouseEmail.isEmpty) {
      setState(() => _error = "Enter your spouse's email first.");
      return;
    }
    await _run(
      () => ref
          .read(familyServiceProvider)
          .createFamily(
            creatorUid: user.uid,
            creatorDisplayName:
                user.displayName ?? user.email!.split('@').first,
            creatorEmail: user.email!,
            spouseEmail: spouseEmail,
          ),
    );
  }

  Future<void> _joinFamily(String familyId) async {
    final user = ref.read(authStateProvider).value;
    if (user == null || user.email == null) return;
    await _run(
      () => ref
          .read(familyServiceProvider)
          .joinFamily(
            familyId: familyId,
            uid: user.uid,
            displayName: user.displayName ?? user.email!.split('@').first,
            email: user.email!,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    return Scaffold(
      appBar: AppBar(title: const Text('Set up your family')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                const SizedBox(height: 16),
              ],
              if (status is FamilyStatusPendingInvite) ...[
                Text("You've been invited to join ${status.familyName}."),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : () => _joinFamily(status.familyId),
                  child: _busy
                      ? const CircularProgressIndicator()
                      : const Text('Join family'),
                ),
              ] else ...[
                const Text(
                  "Let's set up your family. Enter your spouse's Google "
                  "account email so they can join once they sign in.",
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _spouseEmailController,
                  decoration: const InputDecoration(
                    labelText: "Spouse's email",
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _createFamily,
                  child: _busy
                      ? const CircularProgressIndicator()
                      : const Text('Create family'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
