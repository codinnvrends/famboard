import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:famboard/app/services.dart';
import 'package:famboard/data/db/connection.dart';
import 'package:famboard/data/famboard_repository.dart';
import 'package:famboard/data/key_vault.dart';
import 'package:famboard/domain/models.dart';
import 'package:famboard/services/notifications.dart';
import 'package:famboard/services/recurrence.dart';
import 'package:famboard/sync/channel.dart';
import 'package:famboard/sync/transport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A pretend local network: every started transport sees every other one.
class FakeNetwork {
  final Map<String, FakeTransport> _nodes = {};
  bool partitioned = false;

  void join(FakeTransport t) {
    for (final other in _nodes.values) {
      other._see(t);
      t._see(other);
    }
    _nodes[t._deviceId] = t;
  }

  void leave(FakeTransport t) => _nodes.remove(t._deviceId);
}

class FakeTransport implements SyncTransport {
  FakeTransport(this.net);

  final FakeNetwork net;
  late String _deviceId;
  late Set<String> _tags;
  late void Function(DiscoveredPeer) _onPeer;
  late void Function(PeerChannel) _onIncoming;

  @override
  String get name => 'wifi';

  void _see(FakeTransport other) {
    _onPeer(DiscoveredPeer(
      deviceId: other._deviceId,
      tags: other._tags,
      transport: name,
      connect: () async {
        if (net.partitioned) throw StateError('network down');
        final pair = MemoryChannelPair();
        other._onIncoming(pair.b);
        return pair.a;
      },
    ));
  }

  @override
  Future<void> start({
    required String deviceId,
    required Set<String> tags,
    required void Function(DiscoveredPeer peer) onPeer,
    required void Function(String deviceId) onPeerLost,
    required void Function(PeerChannel channel) onIncoming,
  }) async {
    _deviceId = deviceId;
    _tags = tags;
    _onPeer = onPeer;
    _onIncoming = onIncoming;
    net.join(this);
  }

  @override
  Future<void> updateTags(Set<String> tags) async {
    _tags = tags;
    net.leave(this);
    net.join(this);
  }

  @override
  Future<void> stop() async => net.leave(this);
}

class NoopNotifications extends NotificationService {
  @override
  Future<void> init() async {}

  @override
  Future<void> reschedule({
    required List<Entry> entries,
    required bool enabled,
    required int billLeadDays,
    required TimeOfDay digestTime,
    required ReminderTexts texts,
  }) async {}
}

Future<AppServices> _phone(FakeNetwork net, String name) => AppServices.assemble(
      db: openMemoryDatabase(),
      vault: MemoryKeyVault(),
      transports: [FakeTransport(net)],
      notifications: NoopNotifications(),
      defaultDeviceName: name,
    );

Future<void> eventually(Future<bool> Function() check, {Duration timeout = const Duration(seconds: 10)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (await check()) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  fail('Condition not met within $timeout');
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  retryTests();

  test('a family forms, syncs, and handles offline edits and removal', () async {
    final net = FakeNetwork();
    final mum = await _phone(net, "Priya's phone");
    final son = await _phone(net, "Aarav's phone");

    // Mum creates the family and invites her son as a child.
    final family = await mum.repo.createFamily(familyName: 'Sharma home', myName: 'Priya');
    final invite = await mum.repo.createInvite(
      familyId: family.id,
      familyName: 'Sharma home',
      invitedBy: family.memberId,
      role: Role.child,
    );
    final joined = await son.repo.joinFamily(invite, myName: 'Aarav');
    expect(joined.id, family.id);

    await mum.repo.addEntry(
      familyId: family.id,
      memberId: family.memberId,
      draft: const EntryDraft(title: 'Milk 2 L', type: EntryType.needToBuy, categoryId: 'groceries.dairy'),
    );

    // Both apps open on the same network: they find each other and sync.
    await mum.sync.start();
    await son.sync.start();
    await mum.sync.syncAll(force: true);
    await son.sync.syncAll(force: true);

    await eventually(() async => (await son.repo.entries(family.id)).any((e) => e.title == 'Milk 2 L'));
    await eventually(() async => (await mum.repo.members(family.id)).any((m) => m.name == 'Aarav'));
    final sonFamily = await son.store.list(family.id, Entities.family);
    expect(sonFamily.single.fields['name'], 'Sharma home');
    expect((await son.repo.members(family.id)).firstWhere((m) => m.name == 'Aarav').role, Role.child);

    // Offline: both mark the same monthly bill paid. Each creates the next
    // occurrence; after syncing there must be exactly one.
    final billId = await mum.repo.addEntry(
      familyId: family.id,
      memberId: family.memberId,
      draft: EntryDraft(
        title: 'Electricity bill',
        type: EntryType.bill,
        categoryId: 'bills.electricity',
        amount: 1800,
        dueAt: DateTime(2026, 11, 10),
        rrule: RecurrenceRule.monthly(10).toString(),
      ),
    );
    await mum.sync.syncAll(force: true);
    await eventually(() async => (await son.repo.entries(family.id)).any((e) => e.id == billId));

    await mum.sync.stop();
    await son.sync.stop();
    final mumBill = (await mum.repo.entries(family.id)).firstWhere((e) => e.id == billId);
    final sonBill = (await son.repo.entries(family.id)).firstWhere((e) => e.id == billId);
    final nextA = await mum.repo.setStatus(entry: mumBill, memberId: family.memberId, status: EntryStatus.done);
    final nextB = await son.repo.setStatus(entry: sonBill, memberId: joined.memberId, status: EntryStatus.done);
    expect(nextA, nextB, reason: 'deterministic id for the next occurrence');

    await mum.sync.start();
    await son.sync.start();
    await mum.sync.syncAll(force: true);
    await eventually(() async {
      final a = (await mum.repo.entries(family.id)).where((e) => e.title == 'Electricity bill').toList();
      final b = (await son.repo.entries(family.id)).where((e) => e.title == 'Electricity bill').toList();
      return a.length == 2 && b.length == 2;
    });
    final bills = (await mum.repo.entries(family.id)).where((e) => e.title == 'Electricity bill').toList();
    expect(bills.where((e) => e.isOpen).single.dueAt!.month, isNot(10));
    expect(bills.where((e) => e.status == EntryStatus.done).single.id, billId);

    // Mum removes Aarav: his later edits no longer reach her phone.
    await mum.repo.removeMember(family.id, joined.memberId);
    await son.repo.addEntry(
      familyId: family.id,
      memberId: joined.memberId,
      draft: const EntryDraft(title: 'Secret chocolate', type: EntryType.needToBuy, categoryId: 'groceries.snacks'),
    );
    await son.sync.syncAll(force: true);
    await mum.sync.syncAll(force: true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect((await mum.repo.entries(family.id)).any((e) => e.title == 'Secret chocolate'), isFalse);

    await mum.sync.dispose();
    await son.sync.dispose();
  });

  test('a third phone gets data relayed through the second', () async {
    final net = FakeNetwork();
    final a = await _phone(net, 'A');
    final b = await _phone(net, 'B');
    final c = await _phone(net, 'C');
    final fam = await a.repo.createFamily(familyName: 'Home', myName: 'A');
    final invite = await a.repo.createInvite(
      familyId: fam.id, familyName: 'Home', invitedBy: fam.memberId, role: Role.member,
    );
    await b.repo.joinFamily(invite, myName: 'B');
    await c.repo.joinFamily(invite, myName: 'C');
    await a.repo.addEntry(
      familyId: fam.id,
      memberId: fam.memberId,
      draft: const EntryDraft(title: 'Gas cylinder', type: EntryType.needToBuy, categoryId: 'bills.gas'),
    );

    // A and B meet; later B and C meet. A and C never do.
    await a.sync.start();
    await b.sync.start();
    await a.sync.syncAll(force: true);
    await b.sync.syncAll(force: true);
    await eventually(() async => (await b.repo.entries(fam.id)).isNotEmpty);
    await a.sync.stop();

    await c.sync.start();
    await b.sync.syncAll(force: true);
    await c.sync.syncAll(force: true);
    await eventually(() async => (await c.repo.entries(fam.id)).any((e) => e.title == 'Gas cylinder'));

    for (final s in [a, b, c]) {
      await s.sync.dispose();
    }
  });
}

/// Fails to start until [allowed] is set, like Nearby before the user grants
/// the "Nearby devices" permission.
class FlakyTransport extends FakeTransport {
  FlakyTransport(super.net);
  bool allowed = false;
  int attempts = 0;

  @override
  String get name => 'nearby';

  @override
  Future<void> start({
    required String deviceId,
    required Set<String> tags,
    required void Function(DiscoveredPeer peer) onPeer,
    required void Function(String deviceId) onPeerLost,
    required void Function(PeerChannel channel) onIncoming,
  }) async {
    attempts++;
    if (!allowed) throw StateError('8034: MISSING_PERMISSION_BLUETOOTH_ADVERTISE');
    await super.start(
      deviceId: deviceId,
      tags: tags,
      onPeer: onPeer,
      onPeerLost: onPeerLost,
      onIncoming: onIncoming,
    );
  }
}

void retryTests() {
  test('a transport that failed to start is retried and then syncs', () async {
    final net = FakeNetwork();
    final flakyA = FlakyTransport(net);
    final flakyB = FlakyTransport(net);
    final a = await AppServices.assemble(
      db: openMemoryDatabase(), vault: MemoryKeyVault(), transports: [flakyA],
      notifications: NoopNotifications(), defaultDeviceName: 'A',
    );
    final b = await AppServices.assemble(
      db: openMemoryDatabase(), vault: MemoryKeyVault(), transports: [flakyB],
      notifications: NoopNotifications(), defaultDeviceName: 'B',
    );
    final fam = await a.repo.createFamily(familyName: 'Home', myName: 'A');
    final invite = await a.repo.createInvite(
      familyId: fam.id, familyName: 'Home', invitedBy: fam.memberId, role: Role.member,
    );
    await b.repo.joinFamily(invite, myName: 'B');

    // Permission not granted yet: sync runs but the transport is down.
    await a.sync.start();
    await b.sync.start();
    expect(a.sync.current.running, isTrue);
    expect(a.sync.current.transports, isEmpty);
    expect(a.sync.current.transportErrors['nearby'], contains('MISSING_PERMISSION'));

    // Permission granted: a retry brings it up and the phones sync.
    flakyA.allowed = flakyB.allowed = true;
    await a.sync.retryTransports();
    await b.sync.retryTransports();
    expect(a.sync.current.transports, {'nearby'});
    expect(a.sync.current.transportErrors, isEmpty);
    await a.sync.syncAll(force: true);
    await b.sync.syncAll(force: true);
    await eventually(() async => (await a.repo.members(fam.id)).length == 2);
    expect(a.sync.current.log.any((l) => l.message.startsWith('Synced with')), isTrue);

    await a.sync.dispose();
    await b.sync.dispose();
  });
}
