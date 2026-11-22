import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../ui/l10n_ext.dart';
import '../../ui/widgets.dart';
import '../scan/scan_flow.dart';
import '../warranties/warranty_add_flow.dart';
import '../entries/entry_form.dart';
import 'share_handler.dart';

/// Bottom-navigation shell with the family name, sync badge, search and the
/// always-visible add button.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> with ShareHandler {
  /// Branch order in the router.
  static const _today = 0, _lists = 1, _bills = 2, _warranties = 3, _family = 4;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final perms = ref.watch(permsProvider);
    final familyName = ref.watch(familyNameProvider);
    final index = widget.shell.currentIndex;

    // The Bills tab only exists for people allowed to see money.
    final branches = [_today, _lists, if (perms.canSeeBills) _bills, _warranties, _family];
    if (!branches.contains(index)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.shell.goBranch(_today);
      });
    }
    final selected = branches.indexOf(index).clamp(0, branches.length - 1);
    final titles = {
      _today: familyName,
      _lists: l.navLists,
      _bills: l.navBills,
      _warranties: l.navWarranties,
      _family: l.navFamily,
    };

    Widget? fab;
    if (index == _warranties) {
      if (perms.canAddAppliance) {
        fab = FloatingActionButton.extended(
          heroTag: 'add-warranty',
          icon: const Icon(Icons.document_scanner_outlined),
          label: Text(l.warrantyAdd),
          onPressed: () => startApplianceAdd(context, ref),
        );
      }
    } else if (perms.canAddEntries && index != _family) {
      fab = GestureDetector(
        onLongPress: () => showQuickAdd(context, voice: true),
        child: FloatingActionButton.extended(
          heroTag: 'add',
          icon: const Icon(Icons.add),
          label: Text(l.add),
          onPressed: () => showQuickAdd(context),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[index] ?? familyName),
        actions: [
          const SyncBadge(),
          if (perms.canAddEntries && perms.canSeeBills)
            IconButton(
              tooltip: l.scanBill,
              icon: const Icon(Icons.document_scanner_outlined),
              onPressed: () => startBillScan(context, ref),
            ),
          IconButton(
            tooltip: l.search,
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: widget.shell,
      floatingActionButton: fab,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (i) => widget.shell.goBranch(branches[i], initialLocation: branches[i] == index),
        destinations: [
          for (final b in branches)
            switch (b) {
              _today => NavigationDestination(icon: const Icon(Icons.today_outlined), selectedIcon: const Icon(Icons.today), label: l.navToday),
              _lists => NavigationDestination(icon: const Icon(Icons.list_alt_outlined), selectedIcon: const Icon(Icons.list_alt), label: l.navLists),
              _bills => NavigationDestination(icon: const Icon(Icons.receipt_long_outlined), selectedIcon: const Icon(Icons.receipt_long), label: l.navBills),
              _warranties => NavigationDestination(icon: const Icon(Icons.verified_user_outlined), selectedIcon: const Icon(Icons.verified_user), label: l.navWarranties),
              _ => NavigationDestination(icon: const Icon(Icons.family_restroom_outlined), selectedIcon: const Icon(Icons.family_restroom), label: l.navFamily),
            },
        ],
      ),
    );
  }
}
