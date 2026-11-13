import 'package:go_router/go_router.dart';

import '../features/bills/bills_screen.dart';
import '../features/entries/entry_detail_screen.dart';
import '../features/family/family_screen.dart';
import '../features/family/invite_screen.dart';
import '../features/home/home_shell.dart';
import '../features/lists/lists_screen.dart';
import '../features/lists/saved_lists_screen.dart';
import '../features/scan/bill_review_screen.dart';
import '../services/receipt/receipt_parser.dart';
import '../features/onboarding/onboarding_screens.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shopping/shopping_screen.dart';
import '../features/today/today_screen.dart';
import 'services.dart';

GoRouter buildRouter(FamiliesNotifier families) => GoRouter(
      initialLocation: '/today',
      refreshListenable: families,
      redirect: (context, state) {
        final onboarding = state.matchedLocation.startsWith('/welcome');
        if (families.isEmpty && !onboarding) return '/welcome';
        return null;
      },
      routes: [
        GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
        GoRoute(path: '/welcome/create', builder: (_, _) => const CreateFamilyScreen()),
        GoRoute(path: '/welcome/join', builder: (_, _) => const JoinFamilyScreen()),
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => HomeShell(shell: shell),
          branches: [
            StatefulShellBranch(routes: [GoRoute(path: '/today', builder: (_, _) => const TodayScreen())]),
            StatefulShellBranch(routes: [GoRoute(path: '/lists', builder: (_, _) => const ListsScreen())]),
            StatefulShellBranch(routes: [GoRoute(path: '/bills', builder: (_, _) => const BillsScreen())]),
            StatefulShellBranch(routes: [GoRoute(path: '/family', builder: (_, _) => const FamilyScreen())]),
          ],
        ),
        GoRoute(
          path: '/entry/:id',
          builder: (_, state) => EntryDetailScreen(entryId: state.pathParameters['id']!),
        ),
        GoRoute(path: '/shopping', builder: (_, _) => const ShoppingScreen()),
        GoRoute(path: '/search', builder: (_, _) => const SearchScreen()),
        GoRoute(path: '/invite', builder: (_, _) => const InviteScreen()),
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        GoRoute(path: '/saved-lists', builder: (_, _) => const SavedListsScreen()),
        GoRoute(
          path: '/saved-lists/:id',
          builder: (_, state) => SavedListScreen(listId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/bill-review',
          redirect: (_, state) => state.extra is ParsedBill ? null : '/saved-lists',
          builder: (_, state) => BillReviewScreen(bill: state.extra! as ParsedBill),
        ),
      ],
    );
