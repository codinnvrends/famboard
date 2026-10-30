# FamBoard

An offline-first family household board. Family members note what's needed, what's broken and what's due; FamBoard sorts it automatically, reminds you, and syncs between family phones over **Wi‑Fi or Bluetooth with no internet**.

This release covers the spec's phases 0–2 (single-device MVP + offline family sync), with voice entry included in the first release.

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
| Reminders | Offline local notifications on the due date and N days before (bills default 3), daily summary |
| Family | Create, join by QR (15-minute invite), roles (admin, member, child, viewer), change role, remove member, multiple families per phone |
| Sync | Own engine, no third-party account: same Wi‑Fi (mDNS + TCP, Android ↔ iOS) and Android Bluetooth/Wi‑Fi Direct (Nearby Connections); encrypted; sync badge, "Sync now", nearby phones |
| Data | Encrypted database (SQLite3MultipleCiphers), CSV/JSON export, passphrase-encrypted backup and restore |
| Languages | English and Hindi UI; large-text mode |

## Getting started

Requires Flutter 3.47+ (Dart 3.13+).

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # only after changing lib/data/db/database.dart
flutter run
```

Generated files (`lib/data/db/database.g.dart`, `lib/l10n/app_localizations*.dart`) are committed, so `flutter run` works straight after `pub get`.

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
- **Security.** Joining needs the family key from the in-person QR. Each session derives fresh keys from an X25519 exchange salted with the family key; a phone without the key can't decrypt the first frame. Removed members' devices are refused.

## Project layout

```
lib/
  core/         HLC, ids, text helpers
  domain/       models, merge rules, categories, invites, permissions, view logic
  data/         Drift database, record store + change log, repository, settings, key vault
  sync/         channel framing, secure channel, sync session, LAN + Nearby transports, manager
  services/     categorizer, recurrence, text/SMS extraction, reminders, voice, backup, share intake
  features/     screens: today, lists, bills, shopping, entries, family, onboarding, settings, search
  ui/           shared widgets, formatting, localisation helpers
  l10n/         English and Hindi strings (ARB)
test/           64 tests: merge convergence, record store, protocol + crypto,
                end-to-end multi-phone sync, categorizer, recurrence, extraction, views, UI flow
```

## Tests

```bash
flutter test
flutter analyze
```

`test/end_to_end_sync_test.dart` runs whole app stacks on a simulated network: create → invite → join → sync, two phones completing the same recurring bill offline, relay through a third phone, and a removed member being refused.

## Known limitations in this release

- **Sync runs while the app is open.** There's no background service yet; reopening the app syncs straight away.
- **iOS** builds from this project but hasn't been run on a device here (no Mac in the build environment). Same-Wi‑Fi sync works on iOS; no-Wi‑Fi sync on iPhone (Multipeer) is Phase 3. iOS has no share extension yet, so users paste bill SMS instead.
- **Removing a member** stops other phones syncing with them but doesn't rotate the family key, so a removed phone keeps what it already had.
- **Photos** on entries (FR-10) and the **child approval flow** (Proposed status) aren't built yet; the latter is planned for P5.
- **Quantity merge** uses last-writer-wins rather than the spec's "max of both", because "max" would stop anyone lowering a quantity.
- **Automatic SMS reading** (FR-44) is P5; sharing or pasting an SMS works now.
- The **web app** is Phase 4.

See the product spec for the full roadmap.
