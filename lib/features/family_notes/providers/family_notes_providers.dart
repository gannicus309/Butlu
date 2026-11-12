import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart' show familyIdProvider;

/// The family's notes for Gemini (`/families/{id}/notes/family`): food
/// likes and dislikes, diets, routines -- anything that makes answers fit
/// this household. Shared by everyone in the family.
final familyNotesRefProvider =
    Provider<DocumentReference<Map<String, dynamic>>>(
      (ref) => FirebaseFirestore.instance
          .collection('families')
          .doc(ref.watch(familyIdProvider))
          .collection('notes')
          .doc('family'),
      dependencies: [familyIdProvider],
    );

final familyNotesProvider = StreamProvider<String>(
  (ref) => ref
      .watch(familyNotesRefProvider)
      .snapshots()
      .map((s) => s.data()?['text'] as String? ?? ''),
  dependencies: [familyNotesRefProvider],
);
