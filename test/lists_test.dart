import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:famboard/app/services.dart';
import 'package:famboard/data/db/connection.dart';
import 'package:famboard/data/key_vault.dart';
import 'package:famboard/domain/models.dart';
import 'package:famboard/features/scan/bill_review_screen.dart' show addItemsToBoard;
import 'package:famboard/services/lists/list_export.dart';
import 'package:famboard/services/receipt/ocr_types.dart';
import 'package:famboard/services/receipt/receipt_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'end_to_end_sync_test.dart' show FakeNetwork, FakeTransport, NoopNotifications, eventually;

Future<AppServices> _phone(FakeNetwork net, String name) => AppServices.assemble(
      db: openMemoryDatabase(),
      vault: MemoryKeyVault(),
      transports: [FakeTransport(net)],
      notifications: NoopNotifications(),
      defaultDeviceName: name,
    );

ListItem _item(String name, {double? q, String? unit, double? amount, bool checked = false}) =>
    ListItem(id: '', listId: '', name: name, position: 0, quantity: q, unit: unit, amount: amount, checked: checked);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('a scanned bill saved as a list reaches the other phone; ticks sync too', () async {
    final net = FakeNetwork();
    final mum = await _phone(net, 'Mum');
    final dad = await _phone(net, 'Dad');
    final fam = await mum.repo.createFamily(familyName: 'Home', myName: 'Priya');
    final dadLocal = await dad.repo.joinFamily(
      await mum.repo.createInvite(familyId: fam.id, familyName: 'Home', invitedBy: fam.memberId, role: Role.member),
      myName: 'Raj',
    );

    final page = OcrPage.fromJson(
        jsonDecode(File('test/fixtures/bills/maatha_bakery.json').readAsStringSync()) as Map<String, Object?>);
    final bill = mum.billScanner.parser.parse(page);
    final listId = await mum.repo.createList(
      familyId: fam.id,
      memberId: fam.memberId,
      name: 'Maatha bakery',
      kind: ListKind.grocery,
      items: [
        for (final i in bill.items)
          ListItem(id: '', listId: '', name: i.name, position: 0, quantity: i.quantity, unit: i.unit, amount: i.amount),
      ],
      storeName: bill.store,
      billTotal: bill.printedTotal,
      fromBill: true,
    );

    await mum.sync.start();
    await dad.sync.start();
    await mum.sync.syncAll(force: true);
    await eventually(() async => (await dad.repo.listItems(fam.id, listId)).length == bill.items.length);
    final onDad = await dad.repo.listItems(fam.id, listId);
    expect(onDad.map((i) => i.name), bill.items.map((i) => i.name), reason: 'order kept');

    await dad.repo.updateListItem(fam.id, onDad.first, {'checked': true});
    await dad.repo.addListItem(fam.id, listId, 'Paneer');
    await dad.sync.syncAll(force: true);
    await eventually(() async {
      final items = await mum.repo.listItems(fam.id, listId);
      return items.first.checked && items.last.name == 'Paneer';
    });

    // Only unticked items go to the board, and duplicates are skipped.
    final remaining = (await mum.repo.listItems(fam.id, listId)).where((i) => !i.checked).toList();
    final n1 = await addItemsToBoard(mum.repo, fam.id, fam.memberId,
        [for (final i in remaining) (i.name, i.categoryId, i.quantity, i.unit)]);
    expect(n1, remaining.length);
    final n2 = await addItemsToBoard(mum.repo, fam.id, fam.memberId, [('Paneer', null, null, null)]);
    expect(n2, 0);
    final board = await mum.repo.entries(fam.id);
    expect(board.every((e) => e.type == EntryType.needToBuy), isTrue);

    await mum.repo.resetList(fam.id, listId);
    expect((await mum.repo.listItems(fam.id, listId)).any((i) => i.checked), isFalse);
    await dad.repo.deleteList(fam.id, listId);
    await dad.sync.syncAll(force: true);
    await eventually(() async => (await mum.repo.listItems(fam.id, listId)).isEmpty);
    expect(dadLocal.id, fam.id);

    await mum.sync.dispose();
    await dad.sync.dispose();
  });

  group('export', () {
    final list = SavedList(
      id: 'l', familyId: 'f', name: 'DMart · 12 Oct', kind: ListKind.grocery, createdAt: DateTime(2026, 10, 12),
      store: 'DMart', billDate: DateTime(2026, 10, 12),
    );
    final items = [
      _item('Tata Salt 1 kg', q: 4, amount: 116),
      _item('Dal Chana', q: 3.146, unit: 'kg', amount: 298.87, checked: true),
      _item('दूध, "full cream"', q: 2, unit: 'L'),
    ];

    test('message text is a checklist; prices only when asked', () {
      final text = const ListExport().text(list, items);
      expect(text, contains('🛒 *DMart · 12 Oct*'));
      expect(text, contains('☐ Tata Salt 1 kg — 4'));
      expect(text, contains('☑ Dal Chana — 3.146 kg'));
      expect(text, isNot(contains('₹')));
      final priced = const ListExport().text(list, items, withPrices: true, includeChecked: false);
      expect(priced, contains('Tata Salt 1 kg — 4  ₹116'));
      expect(priced, isNot(contains('Dal')));
      expect(priced, contains('Total ₹116'));
    });

    test('CSV quotes commas and quotes', () {
      final csv = const ListExport().csv(list, items).split('\r\n');
      expect(csv.first, 'Item,Quantity,Unit,Rate,Amount,Bought');
      expect(csv[2], 'Dal Chana,3.146,kg,,298.87,yes');
      expect(csv[3], '"दूध, ""full cream""",2,L,,,');
    });

    test('PDF renders with Hindi text and rupee sign', () async {
      ByteData font(String f) => ByteData.sublistView(File('assets/fonts/$f').readAsBytesSync());
      final bytes = await const ListExport().pdf(
        list, items,
        regular: font('NotoSansDevanagari-Regular.ttf'),
        bold: font('NotoSansDevanagari-Bold.ttf'),
      );
      expect(utf8.decode(bytes.sublist(0, 5), allowMalformed: true), '%PDF-');
      expect(bytes.length, greaterThan(2000));
    });

    test('file names are plain', () {
      expect(ListExport.fileStem('DMart · 12 Oct', DateTime(2026, 10, 12)), 'FamBoard-DMart-12-Oct-2026-10-12');
      expect(ListExport.fileStem('किराना', DateTime(2026, 1, 2)), 'FamBoard-list-2026-01-02');
    });
  });

  test('parser categorizes bill items with the shared categorizer', () {
    final page = OcrPage.fromJson(
        jsonDecode(File('test/fixtures/bills/dmart_1.json').readAsStringSync()) as Map<String, Object?>);
    final bill = ReceiptParser().parse(page);
    final salt = bill.items.firstWhere((i) => i.name.contains('Salt 1 kg'));
    expect(salt.categoryId, startsWith('groceries'));
  });
}
