import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../features/inventory/models/expiry_parser.dart';

/// Outcome of [scanExpiryDate].
sealed class ScanResult {}

/// A date was found.
class ScanFound extends ScanResult {
  ScanFound(this.date);
  final DateTime date;
}

/// Text was read but no date in it -- [text] is what was seen, to show the
/// user why.
class ScanNoDate extends ScanResult {
  ScanNoDate(this.text);
  final List<String> text;
}

class ScanFailed extends ScanResult {
  ScanFailed(this.message);
  final String message;
}

const _channel = MethodChannel('butlu/text_recognition');

/// Photographs a pack and reads its best-before date, entirely on the
/// phone (Apple Vision, see ios/Runner/TextRecognizer.swift). Returns null
/// if the user backed out of the camera.
///
/// With [fromLibrary], or where there's no camera (the simulator), it reads
/// a photo from the library instead.
Future<ScanResult?> scanExpiryDate({bool fromLibrary = false}) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
    return ScanFailed('Date scanning needs an iPhone.');
  }
  final picker = ImagePicker();
  final hasCamera =
      await _channel.invokeMethod<bool>('hasCamera').catchError((_) => false) ??
      false;
  final source = !fromLibrary && hasCamera
      ? ImageSource.camera
      : ImageSource.gallery;
  final XFile? photo;
  try {
    photo = await picker.pickImage(
      source: source,
      // Plenty for printed text, and keeps recognition quick.
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 90,
    );
  } on PlatformException catch (e) {
    return ScanFailed(
      e.code == 'camera_access_denied'
          ? 'Allow camera access for Butlu in iOS Settings to scan dates.'
          : "Couldn't open the camera: ${e.message ?? e.code}",
    );
  }
  if (photo == null) return null;

  try {
    final lines =
        await _channel.invokeListMethod<String>('recognizeText', photo.path) ??
        const <String>[];
    final date = parseExpiryDate(lines);
    return date != null ? ScanFound(date) : ScanNoDate(lines);
  } on PlatformException catch (e) {
    return ScanFailed("Couldn't read the photo: ${e.message ?? e.code}");
  }
}
