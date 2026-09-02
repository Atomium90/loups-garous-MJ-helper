import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/data/database/app_database.dart';
import 'package:loup_garou_mj/data/repositories/drift_game_repository.dart';
import 'package:loup_garou_mj/state/providers/game_repository_provider.dart';
import 'package:loup_garou_mj/state/session/session_cursor.dart';
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

  /// A day-2 game: Ana (Voyante, captain, alive), Bo (Loup, alive), Cy
  /// (Chasseur, voted out day 2), Di (never revealed, eaten night 1).
  Future<int> midGame() async {
    final id = await repo.createGame(initialPlayerCount: 4);
    await repo.saveComposition(
      gameId: id,
      playerCount: 4,
      roleCounts: const {'loup_garou': 1, 'voyante': 1, 'chasseur': 1, 'villageois': 1},
    );
    await repo.savePlayerNames(gameId: id, names: const ['Ana', 'Bo', 'Cy', 'Di']);
    await repo.startGame(id);
    final roster = await repo.getRoster(id);
    final rid = roster.map((r) => r.id).toList();
    await repo.assignRoles(playerRowIds: [rid[0]], roleId: 'voyante');
    await repo.assignRoles(playerRowIds: [rid[1]], roleId: 'loup_garou');
    await repo.assignRoles(playerRowIds: [rid[2]], roleId: 'chasseur');

    final engine = GameState(
      players: [
        Player(id: '${rid[0]}', name: 'Ana', roleId: 'voyante'),
        Player(id: '${rid[1]}', name: 'Bo', roleId: 'loup_garou'),
        Player(
          id: '${rid[2]}',
          name: 'Cy',
          roleId: 'chasseur',
          alive: false,
          causeOfDeath: const DayVoteKill(),
          diedOnNight: 2,
          diedOnPhase: GamePhase.day,
        ),
        Player(
          id: '${rid[3]}',
          name: 'Di',
          roleId: 'villageois',
          alive: false,
          causeOfDeath: const WolvesKill(),
          diedOnNight: 1,
          diedOnPhase: GamePhase.night,
        ),
      ],
      nightIndex: 2,
      phase: GamePhase.day,
      captainPlayerId: '${rid[0]}',
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

  testWidgets('renders alive/dead sections, team counts, captain, unknown role, death lines', (
    tester,
  ) async {
    final id = await midGame();
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(repo)],
      initialLocation: '/games/$id/game',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Village'));
    await tester.pumpAndSettle();

    expect(find.text('Le village'), findsOneWidget);
    expect(find.text('2 vivants sur 4'), findsOneWidget);
    expect(find.text('Village 1'), findsOneWidget);
    expect(find.text('Loups 1'), findsOneWidget);
    expect(find.text('VIVANTS'), findsOneWidget);
    expect(find.text('ÉLIMINÉS'), findsOneWidget);

    expect(find.text('Voyante'), findsOneWidget); // Ana
    expect(find.text('Loup-Garou'), findsOneWidget); // Bo
    expect(find.text('Chasseur'), findsOneWidget); // Cy (dead, revealed)
    expect(find.text('Rôle inconnu'), findsOneWidget); // Di

    expect(find.text('Jour 2 · vote du village'), findsOneWidget);
    expect(find.text('Nuit 1 · Loups'), findsOneWidget);
  });

  testWidgets('"Terminer la partie" opens the end-of-game screen', (tester) async {
    final id = await midGame();
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(repo)],
      initialLocation: '/games/$id/game',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Village'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Terminer la partie'));
    await tester.pumpAndSettle();

    expect(find.text('Qui gagne ?'), findsOneWidget);
  });
}
