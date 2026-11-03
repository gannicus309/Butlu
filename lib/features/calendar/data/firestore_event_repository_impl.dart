import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/calendar_category.dart';
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

  CollectionReference<Map<String, dynamic>> get _events =>
      _firestore.collection('families').doc(familyId).collection('events');

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
    final snapshot = await _events
        .where(field, isEqualTo: externalId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return _fromDoc(snapshot.docs.first);
  }

  @override
  Future<void> upsert(CalendarEvent event) async {
    await _events.doc(event.id).set(_toMap(event));
  }

  /// Firestore allows 500 writes per batch; this leaves headroom.
  static const _batchSize = 450;

  @override
  Future<void> upsertAll(List<CalendarEvent> events) async {
    for (var i = 0; i < events.length; i += _batchSize) {
      final batch = _firestore.batch();
      for (final event in events.skip(i).take(_batchSize)) {
        batch.set(_events.doc(event.id), _toMap(event));
      }
      await batch.commit();
    }
  }

  @override
  Future<void> softDeleteAll(List<String> eventIds) async {
    for (var i = 0; i < eventIds.length; i += _batchSize) {
      final batch = _firestore.batch();
      for (final id in eventIds.skip(i).take(_batchSize)) {
        batch.update(_events.doc(id), _softDeleteFields);
      }
      await batch.commit();
    }
  }

  Map<String, Object> get _softDeleteFields => {
    'deleted': true,
    'lastModifiedAt': FieldValue.serverTimestamp(),
    'lastModifiedBy': EventSource.butlu.name,
  };

  @override
  Future<void> softDelete(String eventId) async {
    await _events.doc(eventId).update(_softDeleteFields);
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
    'calendar': {
      'name': event.calendarName,
      'colorHex': event.colorHex,
      'category': event.category?.name,
    },
    'lastModifiedAt': Timestamp.fromDate(event.lastModifiedAt),
    'lastModifiedBy': event.lastModifiedBy.name,
    'deleted': event.deleted,
  };

  CalendarEvent _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
      _fromData(doc.id, doc.data());

  CalendarEvent _fromData(String id, Map<String, dynamic> data) {
    final external = data['external'] as Map<String, dynamic>?;
    final calendar = data['calendar'] as Map<String, dynamic>?;
    return CalendarEvent(
      id: id,
      title: data['title'] as String,
      notes: data['notes'] as String? ?? '',
      startAt: (data['startAt'] as Timestamp).toDate().toUtc(),
      endAt: (data['endAt'] as Timestamp).toDate().toUtc(),
      isAllDay: data['isAllDay'] as bool? ?? false,
      timeZone: data['timeZone'] as String,
      source: EventSource.values.byName(data['source'] as String),
      createdByUid: data['createdByUid'] as String,
      originDeviceId: data['originDeviceId'] as String?,
      iosRef: _refFromMap(external?['ios']),
      outlookRef: _refFromMap(external?['outlook']),
      calendarName: calendar?['name'] as String?,
      colorHex: calendar?['colorHex'] as String?,
      category: CalendarCategory.values
          .asNameMap()[calendar?['category'] as String?],
      // softDelete writes a server timestamp, which reads back as null
      // until the server has confirmed it.
      lastModifiedAt:
          (data['lastModifiedAt'] as Timestamp?)?.toDate().toUtc() ??
          DateTime.now().toUtc(),
      lastModifiedBy: EventSource.values.byName(
        data['lastModifiedBy'] as String,
      ),
      deleted: data['deleted'] as bool? ?? false,
    );
  }
}
