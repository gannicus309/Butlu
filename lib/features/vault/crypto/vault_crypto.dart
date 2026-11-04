import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// End-to-end encryption for Vault notes.
///
/// Each note's title and body are sealed with AES-256-GCM on the phone
/// before they're written to Firestore, so Firebase (and anyone reading the
/// database) only ever sees ciphertext. The 256-bit key lives in the iOS
/// Keychain (see `VaultKeyStore`) and is never uploaded; it can be written
/// down as a recovery key and typed in on another phone.

final _aes = AesGcm.with256bits();

/// A Vault key with a short public id, so a note can say which key sealed
/// it and a phone can tell "wrong key" from "corrupted" without trying.
class VaultKey {
  VaultKey._(this.bytes, this.id);

  final Uint8List bytes;

  /// First 8 hex digits of SHA-256(key). Safe to store next to the notes:
  /// it identifies the key without revealing anything about it.
  final String id;

  static Future<VaultKey> fromBytes(List<int> bytes) async {
    if (bytes.length != 32) {
      throw const FormatException('A Vault key is 32 bytes');
    }
    final digest = await Sha256().hash(bytes);
    final id = digest.bytes
        .take(4)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return VaultKey._(Uint8List.fromList(bytes), id);
  }

  static Future<VaultKey> generate() {
    final random = Random.secure();
    return fromBytes([for (var i = 0; i < 32; i++) random.nextInt(256)]);
  }

  SecretKey get _secret => SecretKey(bytes);
}

/// A note's title and body, sealed. [keyId] says which key can open it.
class SealedNote {
  const SealedNote({required this.keyId, required this.data});

  final String keyId;

  /// base64(nonce ‖ ciphertext ‖ GCM tag).
  final String data;
}

Future<SealedNote> sealNote(
  VaultKey key, {
  required String title,
  required String body,
}) async {
  final box = await _aes.encrypt(
    utf8.encode(jsonEncode({'title': title, 'body': body})),
    secretKey: key._secret,
  );
  return SealedNote(keyId: key.id, data: base64Encode(box.concatenation()));
}

/// Opens a sealed note; throws [SecretBoxAuthenticationError] if the key
/// is wrong or the data was tampered with.
Future<({String title, String body})> openNote(
  VaultKey key,
  SealedNote note,
) async {
  final box = SecretBox.fromConcatenation(
    base64Decode(note.data),
    nonceLength: _aes.nonceLength,
    macLength: _aes.macAlgorithm.macLength,
  );
  final clear = await _aes.decrypt(box, secretKey: key._secret);
  final json = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
  return (
    title: json['title'] as String? ?? '',
    body: json['body'] as String? ?? '',
  );
}

// --- Recovery key -----------------------------------------------------------
//
// The 32-byte key plus a 2-byte checksum, written in Crockford base32 (no
// I, L, O or U, so nothing is ambiguous to read or type) as 14 groups of 4:
//   K7QD-3M9X-...
// The checksum catches typos before a wrong key is tried.

const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

String _base32(List<int> bytes) {
  final out = StringBuffer();
  var buffer = 0, bits = 0;
  for (final b in bytes) {
    buffer = (buffer << 8) | b;
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      out.write(_alphabet[(buffer >> bits) & 31]);
    }
  }
  if (bits > 0) out.write(_alphabet[(buffer << (5 - bits)) & 31]);
  return out.toString();
}

List<int>? _unbase32(String text) {
  final out = <int>[];
  var buffer = 0, bits = 0;
  for (final c in text.split('')) {
    final v = _alphabet.indexOf(c);
    if (v < 0) return null;
    buffer = ((buffer << 5) | v) & 0xFFFF;
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      out.add((buffer >> bits) & 0xFF);
    }
  }
  return out;
}

Future<List<int>> _checksum(List<int> bytes) async =>
    (await Sha256().hash(bytes)).bytes.take(2).toList();

/// The key written out for safe-keeping, e.g. `K7QD-3M9X-...`.
Future<String> recoveryKeyFor(VaultKey key) async {
  final text = _base32([...key.bytes, ...await _checksum(key.bytes)]);
  return [
    for (var i = 0; i < text.length; i += 4)
      text.substring(i, min(i + 4, text.length)),
  ].join('-');
}

/// Reads a recovery key typed back in. Forgiving about spaces, dashes,
/// lower case and the letters people mix up with digits (O→0, I/L→1).
/// Returns null if it isn't a valid key (wrong length or a typo).
Future<VaultKey?> parseRecoveryKey(String input) async {
  final cleaned = input
      .toUpperCase()
      .replaceAll(RegExp(r'[\s\-]'), '')
      .replaceAll('O', '0')
      .replaceAll(RegExp('[IL]'), '1');
  final bytes = _unbase32(cleaned);
  if (bytes == null || bytes.length < 34) return null;
  final key = bytes.sublist(0, 32);
  final check = bytes.sublist(32, 34);
  final expected = await _checksum(key);
  if (check[0] != expected[0] || check[1] != expected[1]) return null;
  return VaultKey.fromBytes(key);
}
