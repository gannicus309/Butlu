import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart' show familyIdProvider;
import '../data/vault_repository.dart';
import '../models/vault_note.dart';

final vaultRepositoryProvider = Provider<VaultRepository>(
  (ref) => VaultRepository(familyId: ref.watch(familyIdProvider)),
  dependencies: [familyIdProvider],
);

final vaultNotesProvider = StreamProvider<List<VaultNote>>(
  (ref) => ref.watch(vaultRepositoryProvider).watchNotes(),
  dependencies: [vaultRepositoryProvider],
);
