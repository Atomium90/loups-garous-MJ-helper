import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/before_night/before_night_screen.dart';
import '../screens/composition/composition_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/players/players_screen.dart';

/// Riverpod-wrapped (not a bare top-level `final`) so it's override-able in tests, consistent
/// with the rest of the app routing everything through Riverpod.
///
/// `/games/:id/composition` (not a flat `/composition/:id`) leaves room for a future
/// `/games/:id/` shell route (the in-game Script/Village/Journal tab bar) without restructuring
/// existing routes - that route isn't added yet, its screen doesn't exist this session.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(path: '/', name: 'home', builder: (_, _) => const HomeScreen()),
      GoRoute(
        path: '/games/:id/composition',
        name: 'composition',
        builder: (_, state) =>
            CompositionScreen(gameId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/games/:id/players',
        name: 'players',
        builder: (_, state) =>
            PlayersScreen(gameId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/games/:id/before-night',
        name: 'beforeNight',
        builder: (_, state) =>
            BeforeNightScreen(gameId: int.parse(state.pathParameters['id']!)),
      ),
    ],
  );
});
