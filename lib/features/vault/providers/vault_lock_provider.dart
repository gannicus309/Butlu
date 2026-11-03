import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

enum VaultLockStatus { locked, authenticating, unlocked }

class VaultLockState {
  const VaultLockState(this.status, {this.message});

  final VaultLockStatus status;

  /// Why the last unlock attempt didn't succeed, for the lock screen to show.
  /// Null after a plain cancel -- that isn't worth an error message.
  final String? message;

  bool get isUnlocked => status == VaultLockStatus.unlocked;
}

/// Face ID (falling back to the device passcode) gate for the Vault tab.
///
/// The Vault starts locked on every launch and locks again whenever the app
/// stops being active -- including going inactive (app switcher, Control
/// Center), not just backgrounded, so the app-switcher snapshot never shows
/// note contents. The one exception is going inactive *because of* our own
/// Face ID prompt, which iOS also reports as inactive; without that guard,
/// the prompt would immediately re-lock the vault it's unlocking.
class VaultLockController extends StateNotifier<VaultLockState> {
  VaultLockController({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication(),
      super(const VaultLockState(VaultLockStatus.locked)) {
    _lifecycle = AppLifecycleListener(
      onInactive: _lockUnlessAuthenticating,
      onHide: lock,
    );
  }

  final LocalAuthentication _auth;
  late final AppLifecycleListener _lifecycle;

  void lock() => state = const VaultLockState(VaultLockStatus.locked);

  void _lockUnlessAuthenticating() {
    if (state.status != VaultLockStatus.authenticating) lock();
  }

  Future<void> unlock() async {
    if (state.status != VaultLockStatus.locked) return;
    state = const VaultLockState(VaultLockStatus.authenticating);
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock your Vault',
        persistAcrossBackgrounding: true,
      );
      state = VaultLockState(
        ok ? VaultLockStatus.unlocked : VaultLockStatus.locked,
      );
    } on LocalAuthException catch (e) {
      state = VaultLockState(
        VaultLockStatus.locked,
        message: _messageFor(e.code),
      );
    }
  }

  static String? _messageFor(LocalAuthExceptionCode code) {
    switch (code) {
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.systemCanceled:
      case LocalAuthExceptionCode.userRequestedFallback:
        return null;
      case LocalAuthExceptionCode.noCredentialsSet:
        return 'Set a passcode in iOS Settings to use the Vault.';
      case LocalAuthExceptionCode.temporaryLockout:
      case LocalAuthExceptionCode.biometricLockout:
        return 'Face ID is locked after too many tries. Unlock your phone with '
            'its passcode, then try again.';
      default:
        return "Couldn't unlock: ${code.name}";
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }
}

final vaultLockProvider =
    StateNotifierProvider<VaultLockController, VaultLockState>(
      (ref) => VaultLockController(),
    );
