import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart' show familyIdProvider;
import '../data/bill_repository.dart';
import '../models/bill.dart';

final billRepositoryProvider = Provider<BillRepository>(
  (ref) => BillRepository(familyId: ref.watch(familyIdProvider)),
  dependencies: [familyIdProvider],
);

final billsProvider = StreamProvider<List<Bill>>(
  (ref) => ref.watch(billRepositoryProvider).watchBills(),
  dependencies: [billRepositoryProvider],
);
