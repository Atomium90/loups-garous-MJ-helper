import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/data/database/app_database.dart';
import 'package:loup_garou_mj/data/models/game_status.dart';
import 'package:loup_garou_mj/data/models/game_winner.dart';
import 'package:loup_garou_mj/state/providers/game_repository_provider.dart';
import 'package:loup_garou_mj/ui/screens/composition/composition_screen.dart';
import 'package:loup_garou_mj/ui/screens/home/home_screen.dart';

import '../../support/fake_game_repository.dart';
import '../../support/pump_app.dart';

void main() {
  testWidgets('empty game list renders the empty-state copy', (tester) async {
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

  testWidgets('a game whose saved state is unreadable offers to delete it from Home', (
    tester,
  ) async {
    final now = DateTime.now();
    final repository = FakeGameRepository(
      initialGames: [
        Game(
          id: 1,
          name: 'Soirée abîmée',
          createdAt: now,
          updatedAt: now,
          playerCount: 9,
          status: GameStatus.inProgress,
          sessionJson: '{not json',
        ),
        Game(
          id: 2,
          name: 'Soirée intacte',
          createdAt: now.subtract(const Duration(days: 1)),
          updatedAt: now.subtract(const Duration(days: 1)),
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
    await tester.pumpAndSettle();

    expect(find.text('Partie illisible'), findsOneWidget);

    await tester.tap(find.text('Soirée abîmée'));
    await tester.pumpAndSettle();
    expect(find.text('Supprimer cette partie'), findsOneWidget);

    await tester.tap(find.text('Supprimer cette partie'));
    await tester.pumpAndSettle();

    expect(find.text('Soirée abîmée'), findsNothing);
    expect(find.text('Partie illisible'), findsNothing);
    // the other game is untouched
    expect(find.text('Soirée intacte'), findsOneWidget);
    expect(await repository.getGame(2), isNotNull);
  });

  testWidgets('cancelling the unreadable-game sheet keeps the game', (tester) async {
    final now = DateTime.now();
    final repository = FakeGameRepository(
      initialGames: [
        Game(
          id: 1,
          name: 'Soirée abîmée',
          createdAt: now,
          updatedAt: now,
          playerCount: 9,
          status: GameStatus.inProgress,
          sessionJson: '[]',
        ),
      ],
    );
    await pumpScreen(
      tester,
      const HomeScreen(),
      overrides: [gameRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Soirée abîmée'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(find.text('Soirée abîmée'), findsOneWidget);
    expect(await repository.getGame(1), isNotNull);
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
    'month, with the winning side',
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
            winner: GameWinner.wolves,
            endedAt: DateTime(2026, 8, 14),
          ),
          Game(
            id: 3,
            name: 'Partie du 26 juillet',
            createdAt: DateTime(2026, 7, 26),
            updatedAt: DateTime(2026, 7, 26),
            playerCount: 8,
            status: GameStatus.completed,
            winner: GameWinner.none,
            endedAt: DateTime(2026, 7, 26),
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
      expect(find.text('Loups'), findsOneWidget); // winning side
      expect(find.text('Annulée'), findsOneWidget); // GameWinner.none
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
