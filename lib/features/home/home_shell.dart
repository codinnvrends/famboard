import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../ui/l10n_ext.dart';
import '../../ui/widgets.dart';
import '../scan/scan_flow.dart';
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
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final perms = ref.watch(permsProvider);
    final familyName = ref.watch(familyNameProvider);
    final index = widget.shell.currentIndex;

    return Scaffold(
      appBar: AppBar(
        title: Text(index == 0 ? familyName : [l.navToday, l.navLists, l.navBills, l.navFamily][index]),
        actions: [
          const SyncBadge(),
          if (perms.canAddEntries)
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
      floatingActionButton: perms.canAddEntries && index != 3
          ? GestureDetector(
              onLongPress: () => showQuickAdd(context, voice: true),
              child: FloatingActionButton.extended(
                heroTag: 'add',
                icon: const Icon(Icons.add),
                label: Text(l.add),
                onPressed: () => showQuickAdd(context),
              ),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => widget.shell.goBranch(i, initialLocation: i == index),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.today_outlined), selectedIcon: const Icon(Icons.today), label: l.navToday),
          NavigationDestination(icon: const Icon(Icons.list_alt_outlined), selectedIcon: const Icon(Icons.list_alt), label: l.navLists),
          NavigationDestination(icon: const Icon(Icons.receipt_long_outlined), selectedIcon: const Icon(Icons.receipt_long), label: l.navBills),
          NavigationDestination(icon: const Icon(Icons.family_restroom_outlined), selectedIcon: const Icon(Icons.family_restroom), label: l.navFamily),
        ],
      ),
    );
  }
}
