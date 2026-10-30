import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models.dart';
import '../../ui/format.dart';
import '../../ui/l10n_ext.dart';
import '../../ui/widgets.dart';

/// Completes an entry the way its type means it: bought, paid or done.
/// Shows undo, and tells the user when the next occurrence was created.
Future<void> completeEntry(BuildContext context, WidgetRef ref, Entry entry) async {
  final services = ref.read(servicesProvider);
  final session = ref.read(sessionProvider);
  if (session == null) return;
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final nextId = await services.repo.setStatus(
    entry: entry,
    memberId: session.memberId,
    status: EntryStatus.done,
    activity: entry.type.isShopping ? 'bought' : 'status',
  );
  String message = entry.type.isShopping ? l.shoppingBought(entry.title) : l.statusDone;
  if (nextId != null) {
    final next = await services.store.get(Entities.entry, nextId);
    final due = next == null ? null : Entry.fromRecord(next).dueAt;
    if (due != null && context.mounted) {
      message = l.nextOccurrence(formatDate(context, due));
    }
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      action: nextId == null
          ? SnackBarAction(
              label: l.undo,
              onPressed: () async {
                final latest = await services.store.get(Entities.entry, entry.id);
                if (latest == null) return;
                await services.repo.setStatus(
                  entry: Entry.fromRecord(latest),
                  memberId: session.memberId,
                  status: entry.status,
                );
              },
            )
          : null,
    ));
}

Future<void> deleteEntryWithUndo(BuildContext context, WidgetRef ref, Entry entry) async {
  final services = ref.read(servicesProvider);
  final session = ref.read(sessionProvider);
  if (session == null) return;
  final l = context.l10n;
  await services.repo.deleteEntry(entry, session.memberId);
  if (!context.mounted) return;
  showSnack(
    context,
    l.entryDeleted,
    action: SnackBarAction(
      label: l.undo,
      onPressed: () => services.repo.restoreEntry(entry, session.memberId),
    ),
  );
}
