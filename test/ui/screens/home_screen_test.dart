import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/data/database/app_database.dart';
import 'package:loup_garou_mj/data/models/game_status.dart';
import 'package:loup_garou_mj/state/providers/game_repository_provider.dart';
import 'package:loup_garou_mj/ui/screens/composition/composition_screen.dart';
import 'package:loup_garou_mj/ui/screens/home/home_screen.dart';

import '../../support/fake_game_repository.dart';
import '../../support/pump_app.dart';

void main() {
  testWidgets('empty game list renders E0 empty-state copy', (tester) async {
    final repository = FakeGameRepository();
    await pumpScreen(
      tester,
      const HomeScreen(),
      overrides: [gameRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pump();

    expect(find.text('Aucune partie'), findsOneWidget);
    expect(find.text('Nouvelle partie'), findsOneWidget);
    expect(find.text('En cours'.toUpperCase()), findsNothing);
  });

  testWidgets('one in-progress game renders under En cours with the fallback resume line', (
    tester,
  ) async {
    final now = DateTime.now();
    final repository = FakeGameRepository(
      initialGames: [
        Game(
          id: 1,
          name: 'Soirée jeux',
          createdAt: now,
          updatedAt: now,
          playerCount: 9,
          status: GameStatus.inProgress,
        ),
      ],
    );
    await pumpScreen(
      tester,
      const HomeScreen(),
      overrides: [gameRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pump();

    expect(find.text('EN COURS'), findsOneWidget);
    expect(find.text('Soirée jeux'), findsOneWidget);
    expect(find.text('Partie en cours'), findsOneWidget);
    expect(find.text('Aucune partie'), findsNothing);
  });

  testWidgets(
    'mixed in-progress + completed games renders both sections, historique grouped by '
    'month, no winner label',
    (tester) async {
      final repository = FakeGameRepository(
        initialGames: [
          Game(
            id: 1,
            name: 'Soirée jeux',
            createdAt: DateTime(2026, 8, 20),
            updatedAt: DateTime(2026, 8, 20),
            playerCount: 9,
            status: GameStatus.inProgress,
          ),
          Game(
            id: 2,
            name: 'Partie du 14 août',
            createdAt: DateTime(2026, 8, 14),
            updatedAt: DateTime(2026, 8, 14),
            playerCount: 9,
            status: GameStatus.completed,
          ),
          Game(
            id: 3,
            name: 'Partie du 26 juillet',
            createdAt: DateTime(2026, 7, 26),
            updatedAt: DateTime(2026, 7, 26),
            playerCount: 8,
            status: GameStatus.completed,
          ),
        ],
      );
      await pumpScreen(
        tester,
        const HomeScreen(),
        overrides: [gameRepositoryProvider.overrideWithValue(repository)],
      );
      await tester.pump();

      expect(find.text('EN COURS'), findsOneWidget);
      expect(find.text('HISTORIQUE'), findsOneWidget);
      expect(find.text('Août 2026'), findsOneWidget);
      expect(find.text('Juillet 2026'), findsOneWidget);
      expect(find.text('Partie du 14 août'), findsOneWidget);
      expect(find.text('Partie du 26 juillet'), findsOneWidget);
      // No `winner` field exists yet: the historique row must never show a fabricated
      // outcome label (see home_screen.dart's _HistoriqueRow doc comment).
      expect(find.text('Loups'), findsNothing);
      expect(find.text('Village'), findsNothing);
    },
  );

  testWidgets('tapping Nouvelle partie creates a game and navigates to Composition', (
    tester,
  ) async {
    final repository = FakeGameRepository();
    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pump();

    expect(repository.allGames, isEmpty);
    await tester.tap(find.text('Nouvelle partie'));
    await tester.pumpAndSettle();

    expect(repository.allGames, hasLength(1));
    expect(repository.allGames.single.status, GameStatus.setup);
    expect(find.byType(CompositionScreen), findsOneWidget);
  });
}
