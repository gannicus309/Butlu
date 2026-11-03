import '../models/device_calendar_info.dart';
import '../models/event_source.dart';
import 'external_calendar_repository.dart';

/// EventKit-backed calendar access. The real implementation (Milestone 2)
/// wraps `device_calendar_plus` and requires `NSCalendarsUsageDescription`
/// permission; kept as a bare interface here so the sync engine and its
/// tests never need a device or a granted permission.
abstract class IosCalendarRepository extends ExternalCalendarRepository {
  @override
  EventSource get source => EventSource.ios;

  /// True once the user has granted calendar access on this device.
  Future<bool> hasPermission();

  Future<bool> requestPermission();

  /// Every calendar on the phone, whether or not it's currently imported.
  Future<List<DeviceCalendarInfo>> listCalendars();

  /// Firebase uid of whoever is signed in on this phone. Events this phone
  /// imported are stamped with it, which is how the sync engine knows which
  /// imported events are its own to clean up when they vanish from iOS.
  String get ownerUid;
}
