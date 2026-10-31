import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:famboard/app/services.dart';
import 'package:famboard/data/db/connection.dart';
import 'package:famboard/data/famboard_repository.dart';
import 'package:famboard/data/key_vault.dart';
import 'package:famboard/domain/invite.dart';
import 'package:famboard/domain/models.dart';
import 'package:famboard/domain/permissions.dart';
import 'package:famboard/services/backup.dart';
import 'package:flutter_test/flutter_test.dart';

import 'end_to_end_sync_test.dart' show FakeNetwork, FakeTransport, NoopNotifications, eventually;

Future<AppServices> _phone(FakeNetwork net, String name) => AppServices.assemble(
      db: openMemoryDatabase(),
      vault: MemoryKeyVault(),
      transports: [FakeTransport(net)],
      notifications: NoopNotifications(),
      defaultDeviceName: name,
    );

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('an admin who reinstalled is brought back by a member as themselves', () async {
    final net = FakeNetwork();
    final mum = await _phone(net, 'Mum');
    final son = await _phone(net, 'Son');
    final fam = await mum.repo.createFamily(familyName: 'Home', myName: 'Priya');
    final sonLocal = await son.repo.joinFamily(
      await mum.repo.createInvite(familyId: fam.id, familyName: 'Home', invitedBy: fam.memberId, role: Role.member),
      myName: 'Aarav',
    );
    await mum.repo.addEntry(
      familyId: fam.id,
      memberId: fam.memberId,
      draft: const EntryDraft(title: 'Milk', type: EntryType.needToBuy, categoryId: 'groceries.dairy'),
    );
    await mum.sync.start();
    await son.sync.start();
    await mum.sync.syncAll(force: true);
    await eventually(() async => (await son.repo.members(fam.id)).length == 2);
    await mum.sync.dispose();

    // Mum uninstalls: a fresh app with nothing in it.
    final mumAgain = await _phone(net, 'Mum (new install)');

    // Aarav is only a member, but can invite Mum back.
    final aaravPerms = Perms(Role.member, sonLocal.memberId);
    expect(aaravPerms.canInvite, isTrue);
    expect(aaravPerms.invitableRoles, isNot(contains(Role.admin)));
    final members = await son.repo.members(fam.id);
    final priya = members.firstWhere((m) => m.name == 'Priya');
    final invite = await son.repo.createInvite(
      familyId: fam.id,
      familyName: 'Home',
      invitedBy: sonLocal.memberId,
      role: Role.member,
      returning: priya,
    );
    // The QR survives encode/decode with the returning member.
    final scanned = FamilyInvite.decode(invite.encode());
    expect(scanned.memberId, priya.id);
    expect(scanned.memberName, 'Priya');

    final rejoined = await mumAgain.repo.joinFamily(scanned, myName: '');
    expect(rejoined.memberId, fam.memberId, reason: 'takes over her old member record');

    await mumAgain.sync.start();
    await son.sync.syncAll(force: true);
    await mumAgain.sync.syncAll(force: true);
    await eventually(() async => (await mumAgain.repo.entries(fam.id)).any((e) => e.title == 'Milk'));
    final after = await mumAgain.repo.members(fam.id);
    expect(after.length, 2, reason: 'no duplicate member');
    final me = after.firstWhere((m) => m.id == rejoined.memberId);
    expect(me.name, 'Priya');
    expect(me.role, Role.admin);

    await son.sync.dispose();
    await mumAgain.sync.dispose();
  });

  group('Backup', () {
    Future<AppServices> withFamily() async {
      final s = await _phone(FakeNetwork(), 'A');
      final fam = await s.repo.createFamily(familyName: 'Sharma home', myName: 'Priya');
      await s.repo.addEntry(
        familyId: fam.id,
        memberId: fam.memberId,
        draft: const EntryDraft(title: 'Electricity bill', type: EntryType.bill, categoryId: 'bills.electricity'),
      );
      return s;
    }

    test('file name is a plain .json document', () {
      expect(
        BackupService.fileName('शर्मा Sharma home!', DateTime(2026, 10, 31)),
        'FamBoard-backup-Sharma-home-2026-10-31.json',
      );
      expect(BackupService.fileName('परिवार', DateTime(2026, 1, 2)), 'FamBoard-backup-family-2026-01-02.json');
    });

    test('round-trips to a fresh install; wrong passphrase is refused', () async {
      final a = await withFamily();
      final fam = (await a.settings.families()).single;
      final bytes = await a.backup.createBackup(fam.id, 'secret-123');
      final doc = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
      expect(doc['famboard'], 'backup');
      expect(utf8.decode(bytes), isNot(contains('Electricity')), reason: 'contents are encrypted');
      expect(BackupService.looksLikeBackup(bytes), isTrue);

      final fresh = await _phone(FakeNetwork(), 'B');
      await expectLater(fresh.backup.restoreBackup(bytes, 'wrong-pass'), throwsA(isA<BackupException>()));
      final restored = await fresh.backup.restoreBackup(bytes, 'secret-123');
      expect(restored.id, fam.id);
      expect((await fresh.repo.entries(fam.id)).single.title, 'Electricity bill');
      expect(await fresh.vault.familyKey(fam.id), await a.vault.familyKey(fam.id));
    });

    test('old binary backups still restore', () async {
      final a = await withFamily();
      final fam = (await a.settings.families()).single;
      // Build a version-1 file the way 0.2.x wrote it.
      final key = (await a.vault.familyKey(fam.id))!;
      final changes = await a.store.allChanges(fam.id);
      final payload = utf8.encode(jsonEncode({
        'family': fam.toJson(),
        'key': base64Encode(key),
        'changes': changes.map((c) => c.toWire()).toList(),
      }));
      final salt = List<int>.generate(16, (i) => i);
      final secret = await Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 1000, bits: 256)
          .deriveKeyFromPassword(password: 'old-pass', nonce: salt);
      final box = await AesGcm.with256bits().encrypt(payload, secretKey: secret);
      final header = utf8.encode(jsonEncode({
        'magic': 'FAMBOARD-BACKUP-1',
        'kdf': 'pbkdf2-sha256',
        'iter': 1000,
        'salt': base64Encode(salt),
        'nonce': base64Encode(box.nonce),
        'mac': base64Encode(box.mac.bytes),
      }));
      final len = Uint8List(4)..buffer.asByteData().setUint32(0, header.length);
      final v1 = Uint8List.fromList([...len, ...header, ...box.cipherText]);

      final fresh = await _phone(FakeNetwork(), 'B');
      final restored = await fresh.backup.restoreBackup(v1, 'old-pass');
      expect(restored.id, fam.id);
      expect((await fresh.repo.entries(fam.id)).single.title, 'Electricity bill');
    });

    test('other files are not mistaken for backups', () {
      expect(BackupService.looksLikeBackup(utf8.encode('{"name": "something else", "x": 1}')), isFalse);
      expect(BackupService.looksLikeBackup(List.filled(100, 7)), isFalse);
    });
  });
}
