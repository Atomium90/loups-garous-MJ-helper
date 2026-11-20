import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/data/database/app_database.dart';
import 'package:loup_garou_mj/data/models/game_status.dart';
import 'package:loup_garou_mj/data/models/game_winner.dart';
import 'package:loup_garou_mj/data/repositories/drift_game_repository.dart';
import 'package:loup_garou_mj/state/providers/game_repository_provider.dart';
import 'package:loup_garou_mj/state/session/session_cursor.dart';
import 'package:loup_garou_mj/ui/widgets/app_button.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../support/pump_app.dart';

void main() {
  late AppDatabase db;
  late DriftGameRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftGameRepository(db);
    addTearDown(db.close);
  });

  Future<int> game({bool wolfAlive = true}) async {
    final id = await repo.createGame(initialPlayerCount: 3);
    await repo.saveComposition(
      gameId: id,
      playerCount: 3,
      roleCounts: const {'loup_garou': 1, 'villageois': 2},
    );
    await repo.savePlayerNames(gameId: id, names: const ['Ana', 'Bo', 'Cy']);
    await repo.startGame(id);
    final rid = (await repo.getRoster(id)).map((r) => r.id).toList();
    // Every card is known, so no dead player's reveal gets in the way of the day screen.
    await repo.assignRoles(playerRowIds: [rid[0]], roleId: 'loup_garou');
    await repo.assignRoles(playerRowIds: [rid[1], rid[2]], roleId: 'villageois');
    final engine = GameState(
      players: [
        Player(
          id: '${rid[0]}',
          name: 'Ana',
          roleId: 'loup_garou',
          alive: wolfAlive,
          causeOfDeath: wolfAlive ? null : const DayVoteKill(),
          diedOnNight: wolfAlive ? null : 2,
          diedOnPhase: wolfAlive ? null : GamePhase.day,
        ),
        Player(id: '${rid[1]}', name: 'Bo', roleId: 'villageois'),
        Player(
          id: '${rid[2]}',
          name: 'Cy',
          roleId: 'villageois',
          alive: false,
          causeOfDeath: const WolvesKill(),
          diedOnNight: 1,
          diedOnPhase: GamePhase.night,
        ),
      ],
      nightIndex: 2,
      phase: GamePhase.day,
    );
    await repo.saveSession(
      gameId: id,
      sessionJson: jsonEncode({
        'engine': GameStateJson.encode(engine),
        'cursor': SessionCursor.nightStart.toJson(),
        'day': DaySnapshot.fresh.toJson(),
      }),
    );
    return id;
  }

  AppButton button(WidgetTester tester, String label) =>
      tester.widget<AppButton>(find.widgetWithText(AppButton, label));

  testWidgets('picking a winner enables the button and completes the game', (tester) async {
    final id = await game();
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(repo)],
      initialLocation: '/games/$id/end',
    );
    await tester.pumpAndSettle();

    expect(find.text('1 Loup vivant, 1 villageois.'), findsOneWidget);
    expect(button(tester, 'Choisissez le vainqueur').onPressed, isNull);

    await tester.tap(find.text('Les Loups-Garous'));
    await tester.pumpAndSettle();
    expect(button(tester, 'Terminer la partie').onPressed, isNotNull);

    await tester.tap(find.widgetWithText(AppButton, 'Terminer la partie'));
    await tester.pumpAndSettle();

    // back on Accueil
    expect(find.text('Mes parties'), findsOneWidget);

    final done = await repo.getGame(id);
    expect(done!.status, GameStatus.completed);
    expect(done.winner, GameWinner.wolves);
  });

  testWidgets('only the winners every game can have are offered when no solo role is in play', (
    tester,
  ) async {
    final id = await game();
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(repo)],
      initialLocation: '/games/$id/end',
    );
    await tester.pumpAndSettle();

    for (final offered in ['Le village', 'Les Loups-Garous', 'Les Amoureux', 'Personne']) {
      expect(find.text(offered), findsOneWidget, reason: offered);
    }
    for (final hidden in ['Le Joueur de Flûte', 'Le Loup-Garou Blanc', "L'Ange", "L'Abominable Sectaire"]) {
      expect(find.text(hidden), findsNothing, reason: hidden);
    }
  });

  group('the proposal on the day screen', () {
    Future<void> openDay(WidgetTester tester, int id) async {
      await tester.binding.setSurfaceSize(const Size(400, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpAppRouter(
        tester,
        overrides: [gameRepositoryProvider.overrideWithValue(repo)],
        initialLocation: '/games/$id/game',
      );
      await tester.pumpAndSettle();
    }

    testWidgets('says nothing while wolves and villagers are both alive', (tester) async {
      await openDay(tester, await game());

      expect(find.textContaining('semble avoir gagné'), findsNothing);
    });

    testWidgets('offers to end the game once no wolf is left, without ending it', (tester) async {
      final id = await game(wolfAlive: false);
      await openDay(tester, id);

      expect(
        find.text('Il ne reste que des villageois : le village semble avoir gagné.'),
        findsOneWidget,
      );
      expect((await repo.getGame(id))!.status, GameStatus.inProgress);

      await tester.tap(find.widgetWithText(AppButton, 'Terminer la partie'));
      await tester.pumpAndSettle();
      expect(find.text('Le village'), findsOneWidget); // the end screen, to pick the winner
    });
  });

  testWidgets('"On continue à jouer" leaves the game running', (tester) async {
    final id = await game();
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(repo)],
      initialLocation: '/games/$id/end',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('On continue à jouer'));
    await tester.pumpAndSettle();

    expect((await repo.getGame(id))!.status, GameStatus.inProgress);
  });
}
