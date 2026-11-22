# FamBoard

An offline-first family household board. Family members note what's needed, what's broken and what's due; FamBoard sorts it automatically, reminds you, and syncs between family phones over **Wi‑Fi or Bluetooth with no internet**.

This release covers the spec's phases 0–2 (single-device MVP + offline family sync), with voice entry included in the first release. Version 1.1 adds a **Warranties** tab and **per-person bill access**.

## What's in this release

| Area | Features |
| --- | --- |
| Entries | Need to buy, Out of stock, Repair, Upgrade, Bill, Task · priority, quantity + unit, amount (₹), due date, assignee, note · claim / let go · start, done, cancel, reopen · soft delete with restore · duplicate warning · per-entry history |
| Quick add | One field; live auto-category as you type; pulls out amounts ("950", "₹1,200"), quantities ("10kg", "2 litres") and dates ("by 12th", "kal", "next monday", "15/11") |
| Voice | Mic in quick add (long-press **+** to start listening), English or Hindi; offline when the phone has the speech pack |
| Auto-categorize | On-device: family corrections → type cues → ~800-term English/Hinglish/Devanagari dictionary → fuzzy match. Corrections are learned and synced to the family |
| Recurring | Daily, weekly, monthly, every 3 months, yearly, every N days; completing one creates the next (no duplicates even when two phones complete it offline) |
| Views | Today (overdue, due today, urgent repairs, out of stock, yours, this week), Lists (all open, daily, weekly, monthly, yearly, recurring, done, deleted) with filters, Bills (to pay / paid this month), Shopping mode by store section, search |
| Bills | Share a bill SMS to FamBoard (Android share sheet) or paste it; amount, due date and biller are detected |
| Bill access | Admins choose who sees bills and money (**Family → member menu → Can see bills & money**). On by default for members, off for children and viewers; admins always see it. Without it: no Bills tab, no bill entries anywhere (Today, Lists, search, reminders), no amounts, no prices on scanned-bill lists, no bill scanning, no CSV/JSON export |
| Warranties | Warranties tab for appliances and gadgets: scan or pick photos of the bill and warranty card (several at once, or add the card later). On-device OCR fills name, brand, model, serial, invoice no., purchase date, shop, price, warranty length, extended warranty and helpline; filled fields are marked "From photo" to check. Each photo is labelled Bill / Warranty card / Other (guessed, changeable). Extended warranty or AMC, service-centre contacts with tap-to-call, service-visit history, and Repair entries linked to the appliance showing its warranty status. Sorted by soonest-ending cover; search, "Ending soon" and "Expired" filters |
| Warranty rules | Admins and members add; whoever added an item can fix it for 24 hours, then only admins edit or delete. Children and viewers can look things up. Prices follow bill access. Reminders 30 and 7 days before a warranty or AMC ends |
| Reminders | Offline local notifications on the due date and N days before (bills default 3), daily summary |
| Family | Create, join by QR (15-minute invite), roles (admin, member, child, viewer), change role, remove member, multiple families per phone |
| Sync | Own engine, no third-party account: same Wi‑Fi (mDNS + TCP, Android ↔ iOS) and Android Bluetooth/Wi‑Fi Direct (Nearby Connections); encrypted; sync badge, "Sync now", nearby phones |
| Data | Encrypted database (SQLite3MultipleCiphers), CSV/JSON export (includes warranties), passphrase-encrypted backup and restore (includes warranty photos) |
| Languages | English and Hindi UI; large-text mode |

## Getting started

Requires Flutter 3.47+ (Dart 3.13+).

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # only after changing lib/data/db/database.dart
flutter run
```

Generated files (`lib/data/db/database.g.dart`, `lib/l10n/app_localizations*.dart`) are committed, so `flutter run` works straight after `pub get`. After changing the ARB files run `flutter gen-l10n`.

Build from an APFS (macOS) or ext4 volume. On exFAT drives Flutter can't take its startup lock (no hard links), and macOS writes `._*` files that end up inside compiled `.jar`s and break the Kotlin build.

Release builds are signed with the upload key in `android/key.properties` (git-ignored); see [store/README.md](store/README.md).

### Try sync on two phones

1. Install on two Android phones. On phone A: **Create a family**.
2. Phone A: **Family → Invite someone**, pick a role. Phone B: **Join a family**, scan the QR.
3. Keep FamBoard open on both. On the same Wi‑Fi they find each other within seconds; with Wi‑Fi off and Bluetooth on, Android phones connect through Nearby Connections. Allow the Bluetooth / nearby-devices permissions when asked.
4. Add something on one phone; it appears on the other. The badge in the top bar shows who you last synced with.

Emulators can't use Nearby, and two emulators usually can't see each other over mDNS, so test sync on real phones. "Copy code" on the invite screen lets you paste an invite instead of scanning.

## How sync works

```
 Phone A                                   Phone B
 UI → Repository → RecordStore             RecordStore ← Repository ← UI
                    │  change log (HLC)       │
                    └── SyncSession ⇄ SyncSession
                         over SecureChannel (X25519 + HKDF + ChaCha20-Poly1305)
                         over LAN socket (mDNS) or Nearby Connections
```

- **Change log.** Every edit is stored as field-level changes stamped with a hybrid logical clock (`lib/core/hlc.dart`). Records are rebuilt from changes with per-field merge rules (`lib/domain/merge.dart`): last writer wins; *done/cancelled* beats a concurrent *in progress* unless someone explicitly reopens; an edit after a delete restores the item. The rules are order-independent, so every phone converges.
- **Exchange.** Peers swap version vectors (newest clock per origin device) and send only what the other lacks, in batches sized for the transport. Changes keep their origin, so data relays A → B → C.
- **Photos.** Warranty photos are compressed to about 200–400 KB and stored in the encrypted database under their SHA-256 (`lib/data/blob_store.dart`); records hold only the ids. After the change exchange, two phones on Wi‑Fi swap the photos the other's records point at but it lacks (`want` / `blob` / `bend`), and each received photo is checked against its hash. Over Bluetooth only the details sync; photos follow on the next Wi‑Fi sync. Phones on older versions don't advertise the `blobs1` capability, so they skip this step and keep syncing records.
- **Security.** Joining needs the family key from the in-person QR. Each session derives fresh keys from an X25519 exchange salted with the family key; a phone without the key can't decrypt the first frame. Removed members' devices are refused.

## Project layout

```
lib/
  core/         HLC, ids, text helpers
  domain/       models, merge rules, categories, invites, permissions, view logic, warranties
  data/         Drift database, record store + change log, photo store, repository, settings, key vault
  sync/         channel framing, secure channel, sync session, LAN + Nearby transports, manager
  services/     categorizer, recurrence, text/SMS extraction, bill + warranty OCR, reminders, voice, backup, share intake
  features/     screens: today, lists, bills, warranties, shopping, entries, family, onboarding, settings, search
  ui/           shared widgets, formatting, localisation helpers
  l10n/         English and Hindi strings (ARB)
test/           172 tests: merge convergence, record store, protocol + crypto,
                end-to-end multi-phone sync, categorizer, recurrence, extraction, views,
                bill OCR, warranties (dates, permissions, reminders, OCR, photo sync,
                backups, database upgrade), UI flows
```

## Tests

```bash
flutter test
flutter analyze
```

`test/end_to_end_sync_test.dart` runs whole app stacks on a simulated network: create → invite → join → sync, two phones completing the same recurring bill offline, relay through a third phone, and a removed member being refused.

Warranty tests:

| File | Covers |
| --- | --- |
| `warranty_test.dart` | Cover dates (calendar months, leap years, explicit end), cover state, sort order, money access and bill visibility, the 24-hour edit window, reminders, repository writes, photo labels |
| `warranty_edge_test.dart` | Boundaries (30-day window, 24-hour window, last covered day), bad synced data, blank fields, hidden prices, reminder horizon and ids, OCR corner cases (labels on the next line, short brand names, number words, helplines, impossible dates), photo de-duplication and family isolation, photo sync with missing or no photos, backups with photos, upgrading a v1 database |
| `warranty_parser_test.dart` | OCR on a store invoice and a warranty card, part-only warranties, row numbers vs serials, date formats, photo labelling, filling only empty fields, shop taken from the bill |
| `warranty_sync_test.dart` | Photos over Wi‑Fi, both ways, relayed, deferred over Bluetooth, older app versions, oversized photos, wrong hash, clean-up of orphaned photos |
| `warranty_widget_test.dart` | Adding by hand; Bills tab and bills hidden without money access (and leaving the tab when access is removed); a child can't add or change; a member's 24-hour window; no price on the page or form without money access |

## Known limitations in this release

- **Sync runs while the app is open.** There's no background service yet; reopening the app syncs straight away.
- **iOS** builds from this project but hasn't been run on a device here (no Mac in the build environment). Same-Wi‑Fi sync works on iOS; no-Wi‑Fi sync on iPhone (Multipeer) is Phase 3. iOS has no share extension yet, so users paste bill SMS instead.
- **Removing a member** stops other phones syncing with them but doesn't rotate the family key, so a removed phone keeps what it already had.
- **Photos** are on warranties only; photos on board entries (FR-10) and the **child approval flow** (Proposed status) aren't built yet; the latter is planned for P5.
- **Bill access is enforced in the app.** Bills still sync to every family phone (one family key), so someone technical could read them from a phone that hides them.
- **Warranty photos sync only over Wi‑Fi.** Over Bluetooth the details arrive and photos show "Arrives on Wi‑Fi sync" until both phones share a network.
- **Warranty OCR** reads English (Latin script) paperwork; Hindi bill scanning is separate. Always check the "From photo" fields: OCR can misread characters (e.g. "/" as "I").
- **Quantity merge** uses last-writer-wins rather than the spec's "max of both", because "max" would stop anyone lowering a quantity.
- **Automatic SMS reading** (FR-44) is P5; sharing or pasting an SMS works now.
- The **web app** is Phase 4.

See the product spec for the full roadmap.
