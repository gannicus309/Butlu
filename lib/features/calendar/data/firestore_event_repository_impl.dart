import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/calendar_event.dart';
import '../models/event_source.dart';
import 'firestore_event_repository.dart';

/// Real implementation backed by `/families/{familyId}/events`. Marshalling
/// lives here, not on [CalendarEvent] itself, so the model stays a plain
/// Dart class the sync engine's tests can construct without touching
/// Firestore.
class FirestoreEventRepositoryImpl implements FirestoreEventRepository {
  FirestoreEventRepositoryImpl({
    required this.familyId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String familyId;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _events => _firestore
      .collection('families')
      .doc(familyId)
      .collection('events');

  @override
  Stream<List<CalendarEvent>> watchEvents() {
    return _events
        .where('deleted', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_fromDoc).toList());
  }

  @override
  Future<List<CalendarEvent>> fetchAll() async {
    final snapshot = await _events.get();
    return snapshot.docs.map(_fromDoc).toList();
  }

  @override
  Future<CalendarEvent?> findByExternalId({
    required EventSource source,
    required String externalId,
  }) async {
    final field = source == EventSource.ios
        ? 'external.ios.eventIdentifier'
        : 'external.outlook.eventIdentifier';
    final snapshot =
        await _events.where(field, isEqualTo: externalId).limit(1).get();
    if (snapshot.docs.isEmpty) return null;
    return _fromDoc(snapshot.docs.first);
  }

  @override
  Future<void> upsert(CalendarEvent event) async {
    await _events.doc(event.id).set(_toMap(event));
  }

  @override
  Future<void> softDelete(String eventId) async {
    await _events.doc(eventId).update({
      'deleted': true,
      'lastModifiedAt': FieldValue.serverTimestamp(),
      'lastModifiedBy': EventSource.butlu.name,
    });
  }

  static Map<String, dynamic>? _refToMap(ExternalRef? ref) => ref?.toJson();

  static ExternalRef? _refFromMap(Object? value) => value == null
      ? null
      : ExternalRef.fromJson(Map<String, dynamic>.from(value as Map));

  Map<String, dynamic> _toMap(CalendarEvent event) => {
        'title': event.title,
        'notes': event.notes,
        'startAt': Timestamp.fromDate(event.startAt),
        'endAt': Timestamp.fromDate(event.endAt),
        'isAllDay': event.isAllDay,
        'timeZone': event.timeZone,
        'source': event.source.name,
        'createdByUid': event.createdByUid,
        'originDeviceId': event.originDeviceId,
        'external': {
          'ios': _refToMap(event.iosRef),
          'outlook': _refToMap(event.outlookRef),
        },
        'lastModifiedAt': Timestamp.fromDate(event.lastModifiedAt),
        'lastModifiedBy': event.lastModifiedBy.name,
        'deleted': event.deleted,
      };

  CalendarEvent _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final external = data['external'] as Map<String, dynamic>?;
    return CalendarEvent(
      id: doc.id,
      title: data['title'] as String,
      notes: data['notes'] as String? ?? '',
      startAt: (data['startAt'] as Timestamp).toDate(),
      endAt: (data['endAt'] as Timestamp).toDate(),
      isAllDay: data['isAllDay'] as bool? ?? false,
      timeZone: data['timeZone'] as String,
      source: EventSource.values.byName(data['source'] as String),
      createdByUid: data['createdByUid'] as String,
      originDeviceId: data['originDeviceId'] as String?,
      iosRef: _refFromMap(external?['ios']),
      outlookRef: _refFromMap(external?['outlook']),
      lastModifiedAt: (data['lastModifiedAt'] as Timestamp).toDate(),
      lastModifiedBy: EventSource.values.byName(data['lastModifiedBy'] as String),
      deleted: data['deleted'] as bool? ?? false,
    );
  }
}
