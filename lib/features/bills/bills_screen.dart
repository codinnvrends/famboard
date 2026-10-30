import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/views.dart';
import '../../ui/format.dart';
import '../../ui/l10n_ext.dart';
import '../../ui/widgets.dart';
import '../entries/entry_actions.dart';
import '../entries/sms_paste.dart';

class BillsScreen extends ConsumerWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider);
    if (session == null) return const SizedBox.shrink();
    final perms = ref.watch(permsProvider);
    final entries = ref.watch(allEntriesProvider(session.familyId)).value ?? const [];
    final view = BillsView.build(entries, now: DateTime.now());

    final addSms = OutlinedButton.icon(
      icon: const Icon(Icons.sms_outlined),
      label: Text(l.addFromSms),
      onPressed: () => showSmsPaste(context),
    );

    if (view.upcoming.isEmpty && view.paidRecently.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: l.billsEmpty,
        body: l.billsEmptyBody,
        action: perms.canAddEntries ? addSms : null,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        if (perms.canSeeAmounts)
          Row(
            children: [
              Expanded(
                child: _Total(
                  label: l.billsStillToPay,
                  value: formatMoney(view.stillToPayThisMonth),
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Total(
                  label: l.billsPaidThisMonth,
                  value: formatMoney(view.paidThisMonth),
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(l.billsAmountsHidden, style: theme.textTheme.bodySmall),
          ),
        if (perms.canAddEntries)
          Padding(padding: const EdgeInsets.only(top: 12), child: Align(alignment: Alignment.centerLeft, child: addSms)),
        if (view.upcoming.isNotEmpty) ...[
          SectionHeader(l.billsUpcoming, count: view.upcoming.length),
          for (final e in view.upcoming)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: EntryTile(e, showCategory: true, onComplete: () => completeEntry(context, ref, e)),
            ),
        ],
        if (view.paidRecently.isNotEmpty) ...[
          SectionHeader(l.billsPaid),
          for (final e in view.paidRecently)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: EntryTile(e)),
        ],
      ],
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
