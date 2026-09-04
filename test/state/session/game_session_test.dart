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
  List<String> reserveRoleIds = const [],
}) async {
  final id = await repo.createGame(initialPlayerCount: 6);
  await repo.saveComposition(
    gameId: id,
    playerCount: 6,
    roleCounts: composition,
    reserveRoleIds: reserveRoleIds,
  );
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
    expect(s.recapDeaths.map((p) => p.id), ['${ids[3]}']);
    expect(s.recapDeaths.single.causeOfDeath, isA<WolvesKill>());

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

  test('full day cycle: reveal a Chasseur, resolve the chain, elect, vote, next night', () async {
    const comp = {'loup_garou': 2, 'voyante': 1, 'sorciere': 1, 'cupidon': 1, 'chasseur': 1};
    final game = await _startedGame(repo, composition: comp);
    final ids = game.seatRowIds; // Ana Bo Cy Di Ed Fi
    String eid(int i) => '${ids[i]}';
    final n = await notifierFor(game.gameId);

    // wake order for this composition: Cupidon, Voyante, Loups, Sorcière
    await n.identifyRole('cupidon', [ids[0]]); // Cupidon = Ana
    await n.pairLovers(eid(1), eid(5)); // lovers: Bo & Fi
    await n.identifyRole('voyante', [ids[1]]); // Voyante = Bo
    await n.skipStep(); // Voyante: "Continuer"
    await n.identifyRole('loup_garou', [ids[2], ids[3]]); // Loups = Cy, Di
    await n.applyAction(WolvesTarget(targetPlayerId: eid(5))); // eat Fi
    await n.identifyRole('sorciere', [ids[4]]); // Sorcière = Ed
    await n.skipStep(); // Sorcière does nothing

    await n.applyAction(const FinalizeNight());
    var s = stateOf(game.gameId);
    expect(s.engine.phase, GamePhase.day);
    expect(s.engine.playerById(eid(5)).alive, isFalse); // Fi, wolves
    expect(s.engine.playerById(eid(1)).alive, isFalse); // Bo, grief
    expect(s.day.loversAck, [eid(1)]);
    expect(s.dayInterrupt, DayInterrupt.reveal); // Fi's card was never noted
    expect(s.unrevealedDead.map((p) => p.id), [eid(5)]);

    await n.revealRole(ids[5], 'chasseur');
    s = stateOf(game.gameId);
    expect(s.engine.cascade?.decision, isA<PendingHunterShot>());
    expect(s.dayInterrupt, DayInterrupt.chain);

    await n.hunterShoot(eid(3)); // the Chasseur takes Di
    s = stateOf(game.gameId);
    expect(s.engine.playerById(eid(3)).alive, isFalse);
    expect(s.engine.cascade, isNull);
    expect(s.dayInterrupt, DayInterrupt.loversAck); // Bo still to acknowledge

    await n.acknowledgeLoversDeaths();
    s = stateOf(game.gameId);
    expect(s.dayInterrupt, isNull);
    expect(s.day.stage, DayStage.recap);

    await n.advanceFromRecap();
    expect(stateOf(game.gameId).day.stage, DayStage.captain);
    await n.electCaptain(eid(2)); // Cy is captain
    s = stateOf(game.gameId);
    expect(s.engine.captainPlayerId, eid(2));
    expect(s.day.stage, DayStage.vote);

    await n.eliminateByVote(eid(4)); // vote out Ed
    s = stateOf(game.gameId);
    expect(s.engine.playerById(eid(4)).alive, isFalse);
    expect(s.day.stage, DayStage.done);

    await n.startNextNight();
    s = stateOf(game.gameId);
    expect(s.engine.nightIndex, 2);
    expect(s.engine.phase, GamePhase.night);
    expect(s.cursor, SessionCursor.nightStart);
    expect(s.day.stage, DayStage.recap);
    // only Cy (a Loup) survives among the night-callers, and the Loups are
    // already known - no re-identification on night 2
    expect(s.tonight.steps.map((st) => st.role.id), ['loup_garou']);
    expect(s.currentStepNeedsIdentify, isFalse);

    final log = (await repo.watchNightLog(game.gameId).first).map((e) => e.line).toList();
    expect(log, containsAll(<String>[
      'Cupidon unit Bo et Fi',
      'Les Loups désignent Fi',
      'Bo meurt de chagrin',
      'Le Chasseur emporte Di',
      'Cy est Capitaine',
      'Le village élimine Ed',
    ]));
  });

  test('with two un-revealed deaths, revealing a Chasseur shows the chain before the next reveal', () async {
    const comp = {
      'loup_garou': 2,
      'voyante': 1,
      'sorciere': 1,
      'villageois': 1,
      'chasseur': 1,
    };
    final game = await _startedGame(repo, composition: comp);
    final ids = game.seatRowIds; // Ana Bo Cy Di Ed Fi
    final n = await notifierFor(game.gameId);

    await n.identifyRole('voyante', [ids[0]]);
    await n.skipStep();
    await n.identifyRole('loup_garou', [ids[1], ids[2]]);
    await n.applyAction(WolvesTarget(targetPlayerId: '${ids[5]}')); // eat Fi
    await n.identifyRole('sorciere', [ids[3]]);
    await n.applyAction(WitchDeathPotion(targetPlayerId: '${ids[4]}')); // poison Ed
    await n.skipStep();
    await n.applyAction(const FinalizeNight());

    var s = stateOf(game.gameId);
    expect(s.unrevealedDead.map((p) => p.id).toSet(), {'${ids[4]}', '${ids[5]}'});
    expect(s.dayInterrupt, DayInterrupt.reveal);

    // reveal the first as the Chasseur -> a cascade is now pending
    final firstDead = int.parse(s.unrevealedDead.first.id);
    await n.revealRole(firstDead, 'chasseur');
    s = stateOf(game.gameId);
    expect(s.engine.cascade?.decision, isA<PendingHunterShot>());
    // the chain wins over the still-un-revealed second death
    expect(s.dayInterrupt, DayInterrupt.chain);
    expect(s.unrevealedDead, isNotEmpty);

    // revealing the second one is refused while the cascade stands
    final secondDead = int.parse(s.unrevealedDead.first.id);
    await n.revealRole(secondDead, 'villageois');
    expect(stateOf(game.gameId).engine.cascade?.decision, isA<PendingHunterShot>());

    // resolve the shot -> back to revealing the second death
    await n.hunterShoot('${ids[0]}');
    s = stateOf(game.gameId);
    expect(s.engine.cascade, isNull);
    expect(s.dayInterrupt, DayInterrupt.reveal);
  });

  test('a fresh container restores a paused Hunter-shot cascade', () async {
    const comp = {'loup_garou': 2, 'voyante': 1, 'sorciere': 1, 'villageois': 1, 'chasseur': 1};
    final game = await _startedGame(repo, composition: comp);
    final ids = game.seatRowIds;
    final n = await notifierFor(game.gameId);

    await n.identifyRole('voyante', [ids[0]]);
    await n.skipStep();
    await n.identifyRole('loup_garou', [ids[1], ids[2]]);
    await n.applyAction(WolvesTarget(targetPlayerId: '${ids[5]}')); // eat Fi
    await n.identifyRole('sorciere', [ids[3]]);
    await n.skipStep();
    await n.applyAction(const FinalizeNight());
    await n.revealRole(ids[5], 'chasseur');
    expect(stateOf(game.gameId).engine.cascade?.decision, isA<PendingHunterShot>());

    final resumed = ProviderContainer(
      overrides: [gameRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(resumed.dispose);
    final s = await resumed.read(gameSessionProvider(game.gameId).future);
    expect(s.engine.cascade?.decision, isA<PendingHunterShot>());
    expect((s.engine.cascade!.decision as PendingHunterShot).deadHunterId, '${ids[5]}');
    expect(s.dayInterrupt, DayInterrupt.chain);
  });

  test('a tie vote eliminates no one, and a role deferred on night 1 is still called night 2', () async {
    final game = await _startedGame(repo, composition: composition);
    final ids = game.seatRowIds;
    final n = await notifierFor(game.gameId);

    // wake order: Voyante, Loups, Sorcière - defer the Voyante entirely
    await n.skipStep(); // "Je noterai plus tard"
    await n.identifyRole('loup_garou', [ids[0], ids[1]]);
    await n.applyAction(WolvesTarget(targetPlayerId: '${ids[4]}'));
    await n.identifyRole('sorciere', [ids[2]]);
    await n.skipStep();
    await n.applyAction(const FinalizeNight());

    await n.advanceFromRecap(); // -> captain (day 1)
    await n.electCaptain(null); // "Pas de Capitaine"
    expect(stateOf(game.gameId).day.stage, DayStage.vote);
    await n.eliminateByVote(null); // tie
    expect(stateOf(game.gameId).day.stage, DayStage.done);

    await n.startNextNight();
    final s = stateOf(game.gameId);
    expect(s.engine.nightIndex, 2);
    expect(s.tonight.steps.map((st) => st.role.id), contains('voyante'));

    final log = (await repo.watchNightLog(game.gameId).first).map((e) => e.line);
    expect(log, contains("Égalité, personne n'est éliminé"));
  });

  group('the Voleur', () {
    const comp = {'voleur': 1, 'loup_garou': 2, 'sorciere': 1, 'villageois': 2};

    test('swapping for a reserve card sets the role on the engine and the roster', () async {
      final game = await _startedGame(
        repo,
        composition: comp,
        reserveRoleIds: const ['voyante', 'chasseur'],
      );
      final ids = game.seatRowIds; // Ana Bo Cy Di Ed Fi
      final n = await notifierFor(game.gameId);

      // wake order: Voleur, Loups, Sorcière (no Voyante in the deal)
      await n.identifyRole('voleur', [ids[0]]); // Voleur = Ana
      await n.voleurSwap(voleurEngineId: '${ids[0]}', stolenRoleId: 'voyante');

      final s = stateOf(game.gameId);
      expect(s.engine.playerById('${ids[0]}').roleId, 'voyante');
      expect((await repo.getRoster(game.gameId))[0].roleId, 'voyante');
      // the stolen Voyante is now called this very night, right after the Voleur
      expect(s.tonight.steps.map((st) => st.role.id), ['voleur', 'voyante', 'loup_garou', 'sorciere']);
      expect(s.cursor.stepIndex, 1); // sitting on the freshly-inserted Voyante step

      final log = (await repo.watchNightLog(game.gameId).first).map((e) => e.line);
      expect(log, contains('Le Voleur échange sa carte contre Voyante'));
    });

    test('keeping his card advances the step and journals it, roster untouched', () async {
      final game = await _startedGame(
        repo,
        composition: comp,
        reserveRoleIds: const ['voyante', 'chasseur'],
      );
      final ids = game.seatRowIds;
      final n = await notifierFor(game.gameId);

      await n.identifyRole('voleur', [ids[0]]);
      await n.voleurSwap(voleurEngineId: '${ids[0]}', stolenRoleId: null);

      final s = stateOf(game.gameId);
      expect(s.engine.playerById('${ids[0]}').roleId, 'voleur');
      expect(s.cursor.stepIndex, 1);
      final log = (await repo.watchNightLog(game.gameId).first).map((e) => e.line);
      expect(log, contains('Le Voleur garde sa carte'));
    });

    test('stealing a Loup makes the Voleur a locked extra, dealt count unchanged', () async {
      final game = await _startedGame(
        repo,
        composition: comp, // loup_garou: 2
        reserveRoleIds: const ['loup_garou', 'chasseur'],
      );
      final ids = game.seatRowIds;
      final n = await notifierFor(game.gameId);

      await n.identifyRole('voleur', [ids[0]]); // Voleur = Ana
      await n.voleurSwap(voleurEngineId: '${ids[0]}', stolenRoleId: 'loup_garou');

      final s = stateOf(game.gameId);
      expect(s.currentStep!.role.id, 'loup_garou');
      expect(s.currentStepNeedsIdentify, isTrue);
      // the 2 dealt wolves are still all to identify; Ana is the +1
      expect(s.dealtHoldersKnown('loup_garou'), 0);
      expect(s.voleurSwapInsFor('loup_garou').map((p) => p.id), ['${ids[0]}']);
    });

    test('a stolenRoleId outside the reserve is refused', () async {
      final game = await _startedGame(
        repo,
        composition: comp,
        reserveRoleIds: const ['voyante', 'chasseur'],
      );
      final ids = game.seatRowIds;
      final n = await notifierFor(game.gameId);

      await n.identifyRole('voleur', [ids[0]]);
      await n.voleurSwap(voleurEngineId: '${ids[0]}', stolenRoleId: 'sorciere');

      final s = stateOf(game.gameId);
      expect(s.engine.playerById('${ids[0]}').roleId, 'voleur'); // unchanged
      expect(s.cursor.stepIndex, 0); // still on the Voleur step
    });
  });

  group('the Voyante', () {
    test('noting an unknown card writes it to the engine and roster, and journals', () async {
      final game = await _startedGame(repo, composition: composition);
      final ids = game.seatRowIds; // Ana Bo Cy Di Ed Fi
      final n = await notifierFor(game.gameId);

      await n.identifyRole('voyante', [ids[0]]); // Voyante = Ana
      await n.seerInspect(targetRowId: ids[3], notedRoleId: 'loup_garou'); // looks at Di

      final s = stateOf(game.gameId);
      expect(s.engine.playerById('${ids[3]}').roleId, 'loup_garou');
      expect((await repo.getRoster(game.gameId))[3].roleId, 'loup_garou');
      expect(s.currentStep!.role.id, 'loup_garou'); // moved to the Loups' step
      final log = (await repo.watchNightLog(game.gameId).first).map((e) => e.line);
      expect(log, contains('La Voyante observe Di'));
    });

    test('looking without noting only journals and advances', () async {
      final game = await _startedGame(repo, composition: composition);
      final ids = game.seatRowIds;
      final n = await notifierFor(game.gameId);

      await n.identifyRole('voyante', [ids[0]]);
      await n.seerInspect(targetRowId: ids[3]);

      expect((await repo.getRoster(game.gameId))[3].roleId, isNull);
      final log = (await repo.watchNightLog(game.gameId).first).map((e) => e.line);
      expect(log, contains('La Voyante observe Di'));
      expect(stateOf(game.gameId).currentStep!.role.id, 'loup_garou');
    });

    test('a Loup she noted counts against the dealt total, not as a Voleur bonus', () async {
      final game = await _startedGame(repo, composition: composition); // loup_garou: 2
      final ids = game.seatRowIds;
      final n = await notifierFor(game.gameId);

      await n.identifyRole('voyante', [ids[0]]);
      await n.seerInspect(targetRowId: ids[3], notedRoleId: 'loup_garou'); // Di is a wolf

      final s = stateOf(game.gameId);
      // Di is one of the 2 dealt wolves, so only 1 is still to identify
      expect(s.dealtHoldersKnown('loup_garou'), 1);
      expect(s.voleurSwapInsFor('loup_garou'), isEmpty); // she's not the Voleur
      expect(s.currentStepNeedsIdentify, isTrue); // one wolf still unknown
    });
  });

  test('the Voleur swap-in survives a force-quit', () async {
    const comp = {'voleur': 1, 'loup_garou': 2, 'sorciere': 1, 'villageois': 2};
    final game = await _startedGame(
      repo,
      composition: comp,
      reserveRoleIds: const ['loup_garou', 'chasseur'],
    );
    final ids = game.seatRowIds;
    final n = await notifierFor(game.gameId);
    await n.identifyRole('voleur', [ids[0]]);
    await n.voleurSwap(voleurEngineId: '${ids[0]}', stolenRoleId: 'loup_garou');

    final resumed = ProviderContainer(
      overrides: [gameRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(resumed.dispose);
    final s = await resumed.read(gameSessionProvider(game.gameId).future);

    expect(s.voleurSwapIn, (playerId: '${ids[0]}', roleId: 'loup_garou'));
    expect(s.dealtHoldersKnown('loup_garou'), 0); // still just the bonus card
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
