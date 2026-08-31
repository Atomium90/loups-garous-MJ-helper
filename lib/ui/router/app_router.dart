import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/before_night/before_night_screen.dart';
import '../screens/composition/composition_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/in_game/in_game_shell.dart';
import '../screens/players/players_screen.dart';

/// Riverpod-wrapped (not a bare top-level `final`) so it's override-able in tests, consistent
/// with the rest of the app routing everything through Riverpod.
///
/// `/games/:id/*` routes: a plain stack for setup (composition, players, before-night), then
/// one `/games/:id/game` route for a running game. The Script/Village/Journal tabs inside it
/// are local state, not sub-routes - go_router forbids a parameterized `StatefulShellBranch`
/// default location, and the tabs never needed independent navigators anyway (the Script
/// tab's step is driven by the persisted GameSession cursor).
final appRouterProvider = Provider<GoRouter>((ref) {
  int idOf(GoRouterState state) => int.parse(state.pathParameters['id']!);

  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (_, _) => const HomeScreen(),
        routes: [
          // Nested under home so its nav stack is [Home, InGameShell] - the OS
          // back button (and a future explicit exit) returns to Accueil.
          GoRoute(
            path: 'games/:id/game',
            name: 'game',
            builder: (_, state) => InGameShell(gameId: idOf(state)),
          ),
        ],
      ),
      GoRoute(
        path: '/games/:id/composition',
        name: 'composition',
        builder: (_, state) => CompositionScreen(gameId: idOf(state)),
      ),
      GoRoute(
        path: '/games/:id/players',
        name: 'players',
        builder: (_, state) => PlayersScreen(gameId: idOf(state)),
      ),
      GoRoute(
        path: '/games/:id/before-night',
        name: 'beforeNight',
        builder: (_, state) => BeforeNightScreen(gameId: idOf(state)),
      ),
    ],
  );
});
