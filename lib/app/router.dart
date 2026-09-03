import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/account/screens/account_screen.dart';
import '../features/bills/screens/bills_screen.dart';
import '../features/calendar/screens/day_detail_screen.dart';
import '../features/calendar/screens/month_view_screen.dart';
import '../features/chores/screens/chores_screen.dart';
import '../features/gemini/screens/gemini_chat_screen.dart';
import '../features/grocery/screens/grocery_screen.dart';
import '../features/meals/screens/meal_plan_screen.dart';
import '../features/more/screens/more_screen.dart';
import '../features/pickup/screens/pickup_screen.dart';
import '../features/vault/screens/note_edit_screen.dart';
import '../features/vault/screens/vault_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/calendar',
  routes: [
    GoRoute(
      path: '/account',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AccountScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          _AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/calendar',
              builder: (context, state) => const MonthViewScreen(),
              routes: [
                GoRoute(
                  path: 'day/:date',
                  builder: (context, state) => DayDetailScreen(
                    date: DateTime.parse(state.pathParameters['date']!),
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/grocery',
              builder: (context, state) => const GroceryScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/chores',
              builder: (context, state) => const ChoresScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/vault',
              builder: (context, state) => const VaultScreen(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) => const NoteEditScreen(),
                ),
                GoRoute(
                  path: 'note/:id',
                  builder: (context, state) => NoteEditScreen(
                    noteId: state.pathParameters['id'],
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/more',
              builder: (context, state) => const MoreScreen(),
              routes: [
                GoRoute(
                  path: 'bills',
                  builder: (context, state) => const BillsScreen(),
                ),
                GoRoute(
                  path: 'pickup',
                  builder: (context, state) => const PickupScreen(),
                ),
                GoRoute(
                  path: 'meals',
                  builder: (context, state) => const MealPlanScreen(),
                ),
                GoRoute(
                  path: 'gemini',
                  builder: (context, state) => const GeminiChatScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

class _AppShell extends StatelessWidget {
  const _AppShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.kitchen_outlined),
            selectedIcon: Icon(Icons.kitchen),
            label: 'Grocery',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Chores',
          ),
          NavigationDestination(
            icon: Icon(Icons.lock_outline),
            selectedIcon: Icon(Icons.lock),
            label: 'Vault',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
