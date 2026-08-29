import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/data/database/app_database.dart';
import 'package:loup_garou_mj/data/models/game_status.dart';
import 'package:loup_garou_mj/data/repositories/drift_game_repository.dart';
import 'package:loup_garou_mj/state/providers/game_repository_provider.dart';
import 'package:loup_garou_mj/state/session/game_session.dart';
import 'package:loup_garou_mj/state/session/session_cursor.dart';
import 'package:rules_engine/rules_engine.dart';

/// A started game with a named 6-seat roster and the given composition, ready
/// for GameSession to seed a night-1 session.
Future<({int gameId, List<int> seatRowIds})> _startedGame(
  DriftGameRepository repo, {
  required Map<String, int> composition,
}) async {
  final id = await repo.createGame(initialPlayerCount: 6);
  await repo.saveComposition(gameId: id, playerCount: 6, roleCounts: composition);
  await repo.savePlayerNames(
    gameId: id,
    names: const ['Ana', 'Bo', 'Cy', 'Di', 'Ed', 'Fi'],
  );
  await repo.startGame(id);
  final roster = await repo.getRoster(id);
  return (gameId: id, seatRowIds: roster.map((r) => r.id).toList());
}

void main() {
  late AppDatabase db;
  late DriftGameRepository repo;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftGameRepository(db);
    container = ProviderContainer(
      overrides: [gameRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(db.close);
    addTearDown(container.dispose);
  });

  const composition = {'loup_garou': 2, 'voyante': 1, 'sorciere': 1, 'villageois': 2};

  Future<GameSession> notifierFor(int gameId) async {
    await container.read(gameSessionProvider(gameId).future);
    return container.read(gameSessionProvider(gameId).notifier);
  }

  GameSessionState stateOf(int gameId) =>
      container.read(gameSessionProvider(gameId)).value!;

  test('build seeds a night-1 session from the roster and derives the script', () async {
    final game = await _startedGame(repo, composition: composition);
    final s = await container.read(gameSessionProvider(game.gameId).future);

    expect(s.engine.nightIndex, 1);
    expect(s.engine.phase, GamePhase.night);
    expect(s.engine.players, hasLength(6));
    // wake order for this composition: Voyante -> Loups -> Sorcière
    expect(s.tonight.steps.map((st) => st.role.id), ['voyante', 'loup_garou', 'sorciere']);
    expect(s.cursor, SessionCursor.nightStart);
    expect((await repo.getGame(game.gameId))!.sessionJson, isNotNull);
  });

  test('a scripted night 1 resolves to day with the wolves\' victim dead', () async {
    final game = await _startedGame(repo, composition: composition);
    final ids = game.seatRowIds; // Ana Bo Cy Di Ed Fi
    final notifier = await notifierFor(game.gameId);

    // Voyante = Cy
    await notifier.identifyRole('voyante', [ids[2]]);
    await notifier.skipStep(); // Voyante's (minimal) act

    // Loups = Ana, Bo
    await notifier.identifyRole('loup_garou', [ids[0], ids[1]]);
    await notifier.applyAction(WolvesTarget(targetPlayerId: '${ids[3]}')); // -> Di

    // Sorcière = Ed, does nothing
    await notifier.identifyRole('sorciere', [ids[4]]);
    await notifier.skipStep();

    expect(stateOf(game.gameId).readyToResolve, isTrue);
    await notifier.applyAction(const FinalizeNight());

    final s = stateOf(game.gameId);
    expect(s.engine.phase, GamePhase.day);
    expect(s.engine.playerById('${ids[3]}').alive, isFalse);
    expect(s.lastResolution, hasLength(1));
    expect(s.lastResolution.single.cause, isA<WolvesKill>());

    // roster roles persisted; Di / Fi stay unknown
    final roster = await repo.getRoster(game.gameId);
    expect(roster.map((r) => r.roleId), [
      'loup_garou',
      'loup_garou',
      'voyante',
      null,
      'sorciere',
      null,
    ]);

    // journal has the wolves' line
    final log = await repo.watchNightLog(game.gameId).first;
    expect(log.map((e) => e.line), contains('Les Loups désignent Di'));
  });

  test('a fresh container restores the exact mid-night state from sessionJson', () async {
    final game = await _startedGame(repo, composition: composition);
    final ids = game.seatRowIds;
    final notifier = await notifierFor(game.gameId);

    await notifier.identifyRole('voyante', [ids[2]]);
    await notifier.skipStep();
    await notifier.identifyRole('loup_garou', [ids[0], ids[1]]);
    await notifier.applyAction(WolvesTarget(targetPlayerId: '${ids[3]}'));

    // simulate a force-quit: brand-new container over the same database
    final resumed = ProviderContainer(
      overrides: [gameRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(resumed.dispose);
    final s = await resumed.read(gameSessionProvider(game.gameId).future);

    expect(s.engine.pendingWolfVictimId, '${ids[3]}');
    expect(s.cursor.stepIndex, 2); // back on the Sorcière step
    expect(s.cursor.subStep, NightSubStep.identify);
  });

  test('startGame does not itself seed the session (build does, lazily)', () async {
    final id = await repo.createGame(initialPlayerCount: 6);
    await repo.saveComposition(gameId: id, playerCount: 6, roleCounts: composition);
    await repo.savePlayerNames(gameId: id, names: const ['a', 'b', 'c', 'd', 'e', 'f']);
    await repo.startGame(id);

    expect((await repo.getGame(id))!.sessionJson, isNull);
    expect((await repo.getGame(id))!.status, GameStatus.inProgress);
  });
}
