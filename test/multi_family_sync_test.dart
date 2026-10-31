import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:famboard/app/services.dart';
import 'package:famboard/data/db/connection.dart';
import 'package:famboard/data/famboard_repository.dart';
import 'package:famboard/data/key_vault.dart';
import 'package:famboard/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'end_to_end_sync_test.dart' show FakeNetwork, FakeTransport, NoopNotifications, eventually;

/// Behaves like real Android discovery: when a phone changes what it
/// advertises, phones that already found it keep the old advert (NSD and
/// Nearby cache it), and every re-advertise restarts the radios.
class StaleAdvertTransport extends FakeTransport {
  StaleAdvertTransport(super.net);

  int restarts = 0;

  @override
  Future<void> updateTags(Set<String> tags) async {
    restarts++;
    // Only the local copy changes; nobody is told.
    await super.updateTagsQuietly(tags);
  }
}

Future<AppServices> _phone(FakeNetwork net, String name) => AppServices.assemble(
      db: openMemoryDatabase(),
      vault: MemoryKeyVault(),
      transports: [StaleAdvertTransport(net)],
      notifications: NoopNotifications(),
      defaultDeviceName: name,
    );

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('a second family syncs between phones that already share the first', () async {
    final net = FakeNetwork();
    final a = await _phone(net, 'A');
    final b = await _phone(net, 'B');

    // Family 1: set up and synced, as on the user's phones.
    final f1 = await a.repo.createFamily(familyName: 'Home', myName: 'Mum');
    await b.repo.joinFamily(
      await a.repo.createInvite(familyId: f1.id, familyName: 'Home', invitedBy: f1.memberId, role: Role.member),
      myName: 'Son',
    );
    await a.sync.start();
    await b.sync.start();
    await a.sync.syncAll(force: true);
    await b.sync.syncAll(force: true);
    await eventually(() async => (await a.repo.members(f1.id)).length == 2);

    // Family 2 created later while both apps are open.
    final f2 = await a.repo.createFamily(familyName: 'Parents home', myName: 'Mum');
    final b2 = await b.repo.joinFamily(
      await a.repo.createInvite(familyId: f2.id, familyName: 'Parents home', invitedBy: f2.memberId, role: Role.member),
      myName: 'Son',
    );
    await b.repo.addEntry(
      familyId: f2.id,
      memberId: b2.memberId,
      draft: const EntryDraft(title: 'Medicines for Nani', type: EntryType.needToBuy, categoryId: 'health.medicines'),
    );

    await a.sync.syncAll(force: true);
    await b.sync.syncAll(force: true);

    await eventually(() async => (await a.repo.members(f2.id)).length == 2);
    await eventually(() async => (await a.repo.entries(f2.id)).any((e) => e.title == 'Medicines for Nani'));
    await eventually(() async =>
        (await b.store.list(f2.id, Entities.family)).any((r) => r.fields['name'] == 'Parents home'));

    // Family 1 is untouched by family 2's data.
    expect((await a.repo.entries(f1.id)).any((e) => e.title == 'Medicines for Nani'), isFalse);

    await a.sync.dispose();
    await b.sync.dispose();
  });

  test('syncing does not restart the radios', () async {
    final net = FakeNetwork();
    final a = await _phone(net, 'A');
    final b = await _phone(net, 'B');
    final f1 = await a.repo.createFamily(familyName: 'Home', myName: 'Mum');
    await b.repo.joinFamily(
      await a.repo.createInvite(familyId: f1.id, familyName: 'Home', invitedBy: f1.memberId, role: Role.member),
      myName: 'Son',
    );
    await a.sync.start();
    await b.sync.start();
    final ta = a.sync.transports.single as StaleAdvertTransport;
    final before = ta.restarts;

    for (var i = 0; i < 3; i++) {
      await a.repo.addEntry(
        familyId: f1.id,
        memberId: f1.memberId,
        draft: EntryDraft(title: 'Item $i', type: EntryType.needToBuy, categoryId: 'groceries'),
      );
      await a.sync.syncAll(force: true);
    }
    await eventually(() async => (await b.repo.entries(f1.id)).length == 3);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(ta.restarts, before, reason: 'only a change in families should re-advertise');

    await a.sync.dispose();
    await b.sync.dispose();
  });
}
