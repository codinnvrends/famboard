import 'package:flutter/material.dart';

import '../../domain/warranty.dart';
import '../../ui/format.dart';
import '../../ui/l10n_ext.dart';

/// "Under warranty till 3 Mar 2027", "Ends in 12 days", "Expired on …".
String coverLabel(BuildContext context, Coverage c, {DateTime? now}) {
  final l = context.l10n;
  final today = now ?? DateTime.now();
  final ends = c.ends;
  if (ends == null) return l.coverUnknown;
  final days = c.daysLeft(today)!;
  if (days < 0) return l.coverExpiredOn(formatLongDate(context, ends));
  if (days == 0) return l.coverEndsToday;
  if (days <= 30) return l.coverEndsInDays(days);
  return l.coverTill(formatLongDate(context, ends));
}

(Color, Color, IconData) coverColors(BuildContext context, CoverState s) {
  final scheme = Theme.of(context).colorScheme;
  return switch (s) {
    CoverState.active => (scheme.primaryContainer, scheme.onPrimaryContainer, Icons.verified_user_outlined),
    CoverState.expiringSoon => (scheme.tertiaryContainer, scheme.onTertiaryContainer, Icons.hourglass_bottom),
    CoverState.expired => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant, Icons.gpp_maybe_outlined),
    CoverState.unknown => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant, Icons.help_outline),
  };
}

/// A rounded badge for a cover period.
class CoverChip extends StatelessWidget {
  const CoverChip(this.cover, {super.key, this.prefix});

  final Coverage cover;

  /// E.g. "AMC" for the extra cover.
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = coverColors(context, cover.state(DateTime.now()));
    final text = coverLabel(context, cover);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              prefix == null ? text : '$prefix · $text',
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Extended warranty" / "AMC".
String extraKindLabel(BuildContext context, ExtraCoverKind k) =>
    k == ExtraCoverKind.amc ? context.l10n.coverAmc : context.l10n.coverExtended;
