import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart' show familyIdProvider;
import '../data/vault_repository.dart';
import '../models/vault_note.dart';
import 'vault_key_provider.dart';

/// Null until this phone has the family's Vault key.
final vaultRepositoryProvider = Provider<VaultRepository?>((ref) {
  final keyState = ref.watch(vaultKeyProvider);
  if (keyState is! VaultKeyReady) return null;
  final repo = VaultRepository(
    familyId: ref.watch(familyIdProvider),
    key: keyState.key,
  );
  // Encrypts any notes saved before Vault encryption existed.
  repo.sealPlainNotes();
  return repo;
}, dependencies: [familyIdProvider, vaultKeyProvider]);

final vaultNotesProvider = StreamProvider<List<VaultNote>>((ref) {
  final repo = ref.watch(vaultRepositoryProvider);
  return repo == null ? const Stream.empty() : repo.watchNotes();
}, dependencies: [vaultRepositoryProvider]);
