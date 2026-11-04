import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../auth/providers/auth_providers.dart' show familyIdProvider;
import '../crypto/vault_crypto.dart';

sealed class VaultKeyState {
  const VaultKeyState();
}

class VaultKeyLoading extends VaultKeyState {
  const VaultKeyLoading();
}

class VaultKeyReady extends VaultKeyState {
  const VaultKeyReady(this.key);
  final VaultKey key;
}

/// This family's Vault is encrypted with a key this phone doesn't have
/// (a new phone, a reinstall, or a second family member): it needs the
/// recovery key typed in.
class VaultKeyMissing extends VaultKeyState {
  const VaultKeyMissing(this.expectedKeyId);
  final String expectedKeyId;
}

class VaultKeyError extends VaultKeyState {
  const VaultKeyError(this.message);
  final String message;
}

/// The Vault key on this phone: kept in the iOS Keychain, only on this
/// device (never in iCloud Keychain or a backup), and never uploaded. The
/// family document records the key's public id, so a phone without the key
/// knows to ask for the recovery key rather than starting a new one.
class VaultKeyController extends StateNotifier<VaultKeyState> {
  VaultKeyController({
    required this.familyId,
    FlutterSecureStorage? storage,
    FirebaseFirestore? firestore,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _firestore = firestore ?? FirebaseFirestore.instance,
       super(const VaultKeyLoading()) {
    _load();
  }

  final String familyId;
  final FlutterSecureStorage _storage;
  final FirebaseFirestore _firestore;

  static const _ios = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  String get _storageKey => 'vault.key.$familyId';

  DocumentReference<Map<String, dynamic>> get _family =>
      _firestore.collection('families').doc(familyId);

  Future<void> _load() async {
    try {
      final stored = await _storage.read(key: _storageKey, iOptions: _ios);
      if (stored != null) {
        state = VaultKeyReady(await VaultKey.fromBytes(base64Decode(stored)));
        return;
      }
      final family = await _family.get();
      final expected = family.data()?['vaultKeyId'] as String?;
      if (expected != null) {
        state = VaultKeyMissing(expected);
        return;
      }
      // First phone to open the Vault: make the family's key.
      final key = await VaultKey.generate();
      await _save(key);
      await _family.update({'vaultKeyId': key.id});
      if (mounted) state = VaultKeyReady(key);
    } catch (e) {
      if (mounted) state = VaultKeyError('$e');
    }
  }

  Future<void> _save(VaultKey key) => _storage.write(
    key: _storageKey,
    value: base64Encode(key.bytes),
    iOptions: _ios,
  );

  /// Takes a typed-in recovery key. Returns an error message to show, or
  /// null on success.
  Future<String?> restore(String recoveryKey) async {
    final key = await parseRecoveryKey(recoveryKey);
    if (key == null) {
      return "That isn't a valid recovery key. Check for typos.";
    }
    final current = state;
    if (current is VaultKeyMissing && key.id != current.expectedKeyId) {
      return "That's a valid key, but not this family's Vault key.";
    }
    await _save(key);
    state = VaultKeyReady(key);
    return null;
  }
}

final vaultKeyProvider =
    StateNotifierProvider<VaultKeyController, VaultKeyState>(
      (ref) => VaultKeyController(familyId: ref.watch(familyIdProvider)),
      dependencies: [familyIdProvider],
    );
