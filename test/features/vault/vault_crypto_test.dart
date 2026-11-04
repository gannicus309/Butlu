import 'package:butlu/features/vault/crypto/vault_crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a note round-trips through seal and open', () async {
    final key = await VaultKey.generate();
    final sealed = await sealNote(
      key,
      title: 'Passport',
      body: 'C01X00T47 · expires 2031',
    );
    expect(sealed.data, isNot(contains('Passport')));
    expect(sealed.keyId, key.id);
    final opened = await openNote(key, sealed);
    expect(opened.title, 'Passport');
    expect(opened.body, 'C01X00T47 · expires 2031');
  });

  test('the same note seals differently each time', () async {
    final key = await VaultKey.generate();
    final a = await sealNote(key, title: 'x', body: 'y');
    final b = await sealNote(key, title: 'x', body: 'y');
    expect(a.data, isNot(b.data));
  });

  test('the wrong key cannot open a note', () async {
    final sealed = await sealNote(
      await VaultKey.generate(),
      title: 'PIN',
      body: '1234',
    );
    await expectLater(
      openNote(await VaultKey.generate(), sealed),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });

  test('a recovery key restores the same key', () async {
    final key = await VaultKey.generate();
    final written = await recoveryKeyFor(key);
    expect(written, matches(RegExp(r'^([0-9A-Z]{4}-)+[0-9A-Z]{1,4}$')));
    final restored = await parseRecoveryKey(written);
    expect(restored!.id, key.id);
    expect(restored.bytes, key.bytes);
  });

  test('recovery keys forgive spacing, case and look-alike letters', () async {
    final key = await VaultKey.generate();
    final written = await recoveryKeyFor(key);
    final sloppy = written
        .toLowerCase()
        .replaceAll('-', ' ')
        .replaceAll('0', 'o')
        .replaceAll('1', 'l');
    expect((await parseRecoveryKey(sloppy))?.id, key.id);
  });

  test('a typo in a recovery key is caught', () async {
    final written = await recoveryKeyFor(await VaultKey.generate());
    final i = written.indexOf(RegExp('[2-9]'));
    final typo =
        written.substring(0, i) +
        (written[i] == '2' ? '3' : '2') +
        written.substring(i + 1);
    expect(await parseRecoveryKey(typo), isNull);
    expect(await parseRecoveryKey('not a key'), isNull);
  });
}
