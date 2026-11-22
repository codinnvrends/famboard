import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/warranty.dart';
import '../../ui/l10n_ext.dart';
import '../../ui/widgets.dart';
import 'cover_status.dart';
import 'photos.dart';

enum _Filter { all, soon, expired }

/// The Warranties tab: every appliance and gadget, soonest-ending cover
/// first, so nothing quietly runs out.
class WarrantiesScreen extends ConsumerStatefulWidget {
  const WarrantiesScreen({super.key});

  @override
  ConsumerState<WarrantiesScreen> createState() => _WarrantiesScreenState();
}

class _WarrantiesScreenState extends ConsumerState<WarrantiesScreen> {
  _Filter _filter = _Filter.all;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final session = ref.watch(sessionProvider);
    if (session == null) return const SizedBox.shrink();
    final perms = ref.watch(permsProvider);
    final all = ref.watch(appliancesProvider(session.familyId)).value ?? const [];
    final today = DateTime.now();

    if (all.isEmpty) {
      return EmptyState(
        icon: Icons.verified_user_outlined,
        title: l.warrantiesEmpty,
        body: perms.canAddAppliance ? l.warrantiesEmptyBody : l.warrantiesEmptyViewer,
      );
    }

    final q = _query.trim().toLowerCase();
    final shown = all.where((a) {
      final state = a.bestCover.state(today);
      final okFilter = switch (_filter) {
        _Filter.all => true,
        _Filter.soon => state == CoverState.expiringSoon,
        _Filter.expired => state == CoverState.expired,
      };
      if (!okFilter) return false;
      if (q.isEmpty) return true;
      return [a.name, a.brand, a.model, a.serial, a.store, a.invoiceNo]
          .whereType<String>()
          .any((s) => s.toLowerCase().contains(q));
    }).toList()
      ..sort((a, b) => compareAppliances(a, b, today));
    final soon = all.where((a) => a.bestCover.state(today) == CoverState.expiringSoon).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: l.warrantySearchHint,
            isDense: true,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: Text(l.warrantyFilterAll),
              selected: _filter == _Filter.all,
              onSelected: (_) => setState(() => _filter = _Filter.all),
            ),
            ChoiceChip(
              label: Text(soon > 0 ? '${l.warrantyFilterSoon} ($soon)' : l.warrantyFilterSoon),
              selected: _filter == _Filter.soon,
              onSelected: (_) => setState(() => _filter = _Filter.soon),
            ),
            ChoiceChip(
              label: Text(l.warrantyFilterExpired),
              selected: _filter == _Filter.expired,
              onSelected: (_) => setState(() => _filter = _Filter.expired),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(l.warrantyNoMatch, textAlign: TextAlign.center),
          ),
        for (final a in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ApplianceTile(a),
          ),
      ],
    );
  }
}

class ApplianceTile extends StatelessWidget {
  const ApplianceTile(this.appliance, {super.key});

  final Appliance appliance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = appliance;
    final sub = [a.brand, a.model].whereType<String>().join(' · ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/appliance/${a.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: a.photos.isEmpty
                      ? ColoredBox(
                          color: theme.colorScheme.secondaryContainer,
                          child: Icon(Icons.kitchen_outlined, color: theme.colorScheme.onSecondaryContainer),
                        )
                      : StoredPhoto(id: a.photos.first),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.name, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (sub.isNotEmpty)
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    const SizedBox(height: 6),
                    CoverChip(a.bestCover, prefix: a.bestIsExtra ? extraKindLabel(context, a.extraKind) : null),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
