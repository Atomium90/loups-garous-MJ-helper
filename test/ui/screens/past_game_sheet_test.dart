import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/data/database/app_database.dart';
import 'package:loup_garou_mj/data/models/game_winner.dart';
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

  testWidgets('a completed game opens the recap: winner, counts, survivors only', (tester) async {
    final id = await repo.createGame(initialPlayerCount: 4);
    await repo.saveComposition(
      gameId: id,
      playerCount: 4,
      roleCounts: const {'loup_garou': 1, 'voyante': 1, 'villageois': 2},
    );
    await repo.savePlayerNames(gameId: id, names: const ['Ana', 'Bo', 'Cy', 'Di']);
    await repo.startGame(id);
    final rid = (await repo.getRoster(id)).map((r) => r.id).toList();
    await repo.assignRoles(playerRowIds: [rid[0]], roleId: 'loup_garou');
    await repo.assignRoles(playerRowIds: [rid[1]], roleId: 'voyante');

    final engine = GameState(
      players: [
        Player(id: '${rid[0]}', name: 'Ana', roleId: 'loup_garou'),
        Player(id: '${rid[1]}', name: 'Bo', roleId: 'voyante'),
        Player(
          id: '${rid[2]}',
          name: 'Cy',
          roleId: 'villageois',
          alive: false,
          causeOfDeath: const WolvesKill(),
          diedOnNight: 1,
          diedOnPhase: GamePhase.night,
        ),
        Player(
          id: '${rid[3]}',
          name: 'Di',
          roleId: 'villageois',
          alive: false,
          causeOfDeath: const DayVoteKill(),
          diedOnNight: 2,
          diedOnPhase: GamePhase.day,
        ),
      ],
      nightIndex: 3,
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
    await repo.endGame(gameId: id, winner: GameWinner.wolves);

    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(repo)],
    );
    await tester.pumpAndSettle();

    // the historique row shows the winning side; tapping it opens the recap
    expect(find.text('Loups'), findsOneWidget);
    await tester.tap(find.text('Loups'));
    await tester.pumpAndSettle();

    expect(find.text('Vainqueurs'), findsOneWidget);
    expect(find.text('Les Loups-Garous'), findsOneWidget);
    expect(find.text('2 sur 4'), findsOneWidget); // survivors
    // survivors' roles are shown; the eliminated stay hidden
    expect(find.text('Loup-Garou'), findsOneWidget);
    expect(find.text('Voyante'), findsOneWidget);
    expect(find.textContaining('2 éliminés restent cachés'), findsOneWidget);
  });
}
