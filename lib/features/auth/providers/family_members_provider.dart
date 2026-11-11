import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart' show familyIdProvider;

/// uid -> display name for every member of the current family. Used
/// anywhere a feature needs to show *who* did something (chore assignee,
/// vault note author) rather than a raw uid.
final familyMembersProvider = StreamProvider<Map<String, String>>((ref) {
  final familyId = ref.watch(familyIdProvider);
  return FirebaseFirestore.instance
      .collection('families')
      .doc(familyId)
      .collection('members')
      .snapshots()
      .map(
        (snapshot) => {
          for (final doc in snapshot.docs)
            doc.id: (doc.data()['displayName'] as String?) ?? 'Someone',
        },
      );
}, dependencies: [familyIdProvider]);
