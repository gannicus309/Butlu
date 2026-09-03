import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart' show familyIdProvider;
import '../data/status_repository.dart';
import '../models/member_status.dart';

final statusRepositoryProvider = Provider<StatusRepository>(
  (ref) => StatusRepository(familyId: ref.watch(familyIdProvider)),
  dependencies: [familyIdProvider],
);

final statusesProvider = StreamProvider<List<MemberStatus>>(
  (ref) => ref.watch(statusRepositoryProvider).watchStatuses(),
  dependencies: [statusRepositoryProvider],
);

const List<String> statusPresets = [
  'On my way',
  'Running late',
  'At daycare/school',
  'Home',
];
