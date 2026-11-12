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

/// Why a photo couldn't be taken or read; [message] is for the user.
class ScanException implements Exception {
  ScanException(this.message);
  final String message;
}

/// Takes a photo of a pack with the camera, or picks one from the library
/// with [fromLibrary] or where there's no camera (the simulator). Null if
/// the user backed out.
Future<XFile?> takePackPhoto({
  bool fromLibrary = false,
  double maxSide = 2000,
}) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
    throw ScanException('Scanning needs an iPhone.');
  }
  final hasCamera =
      await _channel.invokeMethod<bool>('hasCamera').catchError((_) => false) ??
      false;
  try {
    return await ImagePicker().pickImage(
      source: !fromLibrary && hasCamera
          ? ImageSource.camera
          : ImageSource.gallery,
      // Plenty for printed text, and keeps recognition quick.
      maxWidth: maxSide,
      maxHeight: maxSide,
      imageQuality: 90,
    );
  } on PlatformException catch (e) {
    throw ScanException(
      e.code == 'camera_access_denied'
          ? 'Allow camera access for Butlu in iOS Settings to scan packs.'
          : "Couldn't open the camera: ${e.message ?? e.code}",
    );
  }
}

/// The text Apple Vision reads in a photo, on the phone: each line's best
/// reading in order, then other readings of lines it wasn't sure about.
Future<List<String>> recognizeText(String path) async {
  try {
    return await _channel.invokeListMethod<String>('recognizeText', path) ??
        const <String>[];
  } on PlatformException catch (e) {
    throw ScanException("Couldn't read the photo: ${e.message ?? e.code}");
  }
}

/// Photographs a pack and reads its best-before date, entirely on the
/// phone (Apple Vision, see ios/Runner/TextRecognizer.swift). Returns null
/// if the user backed out of the camera.
Future<ScanResult?> scanExpiryDate({bool fromLibrary = false}) async {
  try {
    final photo = await takePackPhoto(fromLibrary: fromLibrary);
    if (photo == null) return null;
    final lines = await recognizeText(photo.path);
    final date = parseExpiryDate(lines);
    return date != null ? ScanFound(date) : ScanNoDate(lines);
  } on ScanException catch (e) {
    return ScanFailed(e.message);
  }
}

/// Product barcodes (EAN/UPC digits) Apple Vision finds in a photo; empty
/// if none, or if detection failed.
Future<List<String>> detectBarcodes(String path) async {
  try {
    return await _channel.invokeListMethod<String>('detectBarcodes', path) ??
        const <String>[];
  } on PlatformException {
    return const <String>[];
  }
}
