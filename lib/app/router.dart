import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/account/screens/account_screen.dart';
import '../features/bills/screens/bills_screen.dart';
import '../features/calendar/screens/calendar_sources_screen.dart';
import '../features/calendar/screens/day_detail_screen.dart';
import '../features/calendar/screens/month_view_screen.dart';
import '../features/chores/screens/chore_load_screen.dart';
import '../features/chores/screens/chores_screen.dart';
import '../features/family_notes/screens/family_notes_screen.dart';
import '../features/gemini/screens/gemini_chat_screen.dart';
import '../features/grocery/screens/shopping_screen.dart';
import '../features/inventory/providers/inventory_providers.dart';
import '../features/inventory/screens/inventory_screen.dart';
import '../features/meals/screens/meal_plan_screen.dart';
import '../features/more/screens/about_screen.dart';
import '../features/more/screens/more_screen.dart';
import '../features/pickup/screens/pickup_screen.dart';
import '../features/vault/screens/note_edit_screen.dart';
import '../features/vault/providers/vault_lock_provider.dart';
import '../features/vault/screens/vault_screen.dart';
import 'theme.dart';

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
    // Ask Gemini from any tab (the ✨ button next to the profile picture),
    // full screen above the tab bar. `?q=` asks a question straight away.
    GoRoute(
      path: '/ask',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          GeminiChatScreen(initialPrompt: state.uri.queryParameters['q']),
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
                  path: 'sources',
                  builder: (context, state) => const CalendarSourcesScreen(),
                ),
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
              builder: (context, state) => const ShoppingScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/inventory',
              builder: (context, state) => const InventoryScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/chores',
              builder: (context, state) => const ChoresScreen(),
              routes: [
                GoRoute(
                  path: 'load',
                  builder: (context, state) => const ChoreLoadScreen(),
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
                  path: 'about',
                  builder: (context, state) => const AboutScreen(),
                ),
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
                  path: 'notes',
                  builder: (context, state) => const FamilyNotesScreen(),
                ),
                GoRoute(
                  path: 'gemini',
                  builder: (context, state) => const GeminiChatScreen(),
                ),
                GoRoute(
                  path: 'vault',
                  builder: (context, state) => const VaultScreen(),
                  routes: [
                    GoRoute(
                      path: 'new',
                      builder: (context, state) => const NoteEditScreen(),
                    ),
                    GoRoute(
                      path: 'note/:id',
                      builder: (context, state) =>
                          NoteEditScreen(noteId: state.pathParameters['id']),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

class _AppShell extends ConsumerWidget {
  const _AppShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static final _tabThemes = [for (final c in kTabAccents) buildButluTheme(c)];

  /// Vault lives under More, so leaving the More tab locks it.
  static const _vaultBranch = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Here rather than on the Inventory screen, which isn't built until its
    // tab is first opened: reminders should follow the inventory from launch.
    ref.listen(inventoryProvider, (previous, next) {
      final items = next.value;
      if (items != null) ref.read(expiryNotifierProvider).reschedule(items);
    });
    // The whole tab -- its screens and the tab bar -- takes on that tab's
    // accent colour, blending over as you switch.
    return AnimatedTheme(
      data: _tabThemes[navigationShell.currentIndex],
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: Scaffold(
        body: _FadeOnTabChange(
          index: navigationShell.currentIndex,
          child: navigationShell,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) {
            if (index != navigationShell.currentIndex) {
              HapticFeedback.selectionClick();
            }
            // Leaving the More tab locks the Vault again (it lives under More),
            // so it never sits open behind another tab.
            if (navigationShell.currentIndex == _vaultBranch &&
                index != _vaultBranch) {
              ref.read(vaultLockProvider.notifier).lock();
            }
            navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            );
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today),
              label: 'Calendar',
            ),
            NavigationDestination(
              icon: Icon(Icons.shopping_cart_outlined),
              selectedIcon: Icon(Icons.shopping_cart),
              label: 'Grocery',
            ),
            NavigationDestination(
              icon: Icon(Icons.kitchen_outlined),
              selectedIcon: Icon(Icons.kitchen),
              label: 'Inventory',
            ),
            NavigationDestination(
              icon: Icon(Icons.checklist_outlined),
              selectedIcon: Icon(Icons.checklist),
              label: 'Chores',
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz),
              selectedIcon: Icon(Icons.more_horiz),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}

/// Fades the tab content in whenever the selected tab changes. Deliberately
/// keeps the same [child] (go_router's IndexedStack of branches) mounted
/// rather than swapping widgets with an AnimatedSwitcher, which would rebuild
/// the branches and lose each tab's scroll position and state.
class _FadeOnTabChange extends StatefulWidget {
  const _FadeOnTabChange({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_FadeOnTabChange> createState() => _FadeOnTabChangeState();
}

class _FadeOnTabChangeState extends State<_FadeOnTabChange>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  @override
  void didUpdateWidget(_FadeOnTabChange oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.015),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}
