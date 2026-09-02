import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/auth_service.dart';
import '../../../services/family_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final familyServiceProvider = Provider<FamilyService>((ref) => FamilyService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

sealed class FamilyStatus {
  const FamilyStatus();
}

class FamilyStatusMember extends FamilyStatus {
  const FamilyStatusMember(this.familyId);
  final String familyId;
}

class FamilyStatusPendingInvite extends FamilyStatus {
  const FamilyStatusPendingInvite(this.familyId, this.familyName);
  final String familyId;
  final String familyName;
}

class FamilyStatusNone extends FamilyStatus {
  const FamilyStatusNone();
}

/// Resolves where the signed-in user stands: already a member, invited but
/// not yet joined, or needs to create a family. Re-runs whenever auth state
/// changes, or when explicitly invalidated after a create/join action.
final familyStatusProvider = FutureProvider<FamilyStatus>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const FamilyStatusNone();

  final familyService = ref.watch(familyServiceProvider);
  final existingId = await familyService.findFamilyIdForMember(user.uid);
  if (existingId != null) return FamilyStatusMember(existingId);

  final email = user.email;
  if (email != null) {
    final pending = await familyService.findPendingInvite(email);
    if (pending != null) {
      return FamilyStatusPendingInvite(pending.familyId, pending.name);
    }
  }

  return const FamilyStatusNone();
});

/// Overridden with the resolved family's id once [FamilyStatusMember] is
/// reached -- see main.dart's `_FamilyGate`. Any provider that reads this
/// before it's overridden has a bug in the auth-gating flow.
final familyIdProvider = Provider<String>((ref) {
  throw UnimplementedError(
    'familyIdProvider must be overridden once a family is resolved.',
  );
});
