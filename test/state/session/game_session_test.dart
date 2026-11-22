import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/data/database/app_database.dart';
import 'package:loup_garou_mj/data/models/game_status.dart';
import 'package:loup_garou_mj/data/models/game_winner.dart';
import 'package:loup_garou_mj/data/repositories/drift_game_repository.dart';
import 'package:loup_garou_mj/state/providers/game_repository_provider.dart';
import 'package:loup_garou_mj/state/session/game_session.dart';
import 'package:loup_garou_mj/data/models/night_log_entry.dart' show JournalPhase;
import 'package:loup_garou_mj/state/session/session_cursor.dart';
import 'package:loup_garou_mj/state/session/session_summary_provider.dart';
import 'package:loup_garou_mj/state/settings/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loup_garou_mj/ui/screens/in_game/script_tab.dart' show unassignedRoles;
import 'package:rules_engine/rules_engine.dart';

import '../../support/journal_text.dart';

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
    expect(frenchJournal(log), contains('Les Loups désignent Di'));
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

    final log = frenchJournal(await repo.watchNightLog(game.gameId).first);
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

    final log = frenchJournal(await repo.watchNightLog(game.gameId).first);
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

      final log = frenchJournal(await repo.watchNightLog(game.gameId).first);
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
      final log = frenchJournal(await repo.watchNightLog(game.gameId).first);
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
      final log = frenchJournal(await repo.watchNightLog(game.gameId).first);
      expect(log, contains('La Voyante observe Di'));
    });

    test('looking without noting only journals and advances', () async {
      final game = await _startedGame(repo, composition: composition);
      final ids = game.seatRowIds;
      final n = await notifierFor(game.gameId);

      await n.identifyRole('voyante', [ids[0]]);
      await n.seerInspect(targetRowId: ids[3]);

      expect((await repo.getRoster(game.gameId))[3].roleId, isNull);
      final log = frenchJournal(await repo.watchNightLog(game.gameId).first);
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

  group('the Abominable Sectaire', () {
    const comp = {'abominable_sectaire': 1, 'loup_garou': 2, 'villageois': 3};

    test('the division is journalled, kept, and moves on to the next step', () async {
      final game = await _startedGame(repo, composition: comp);
      final n = await notifierFor(game.gameId);
      await n.identifyRole('abominable_sectaire', [game.seatRowIds[0]]);

      await n.divideVillage({'${game.seatRowIds[0]}', '${game.seatRowIds[1]}'});

      final s = stateOf(game.gameId);
      expect(s.engine.division?.groupA, {'${game.seatRowIds[0]}', '${game.seatRowIds[1]}'});
      expect(s.currentStep!.role.id, 'loup_garou');
      final log = frenchJournal(await repo.watchNightLog(game.gameId).first);
      expect(log, contains('Le village est divisé : Ana, Bo contre Cy, Di, Ed, Fi'));
    });

    test('his victory is proposed once the other group is eliminated', () async {
      final game = await _startedGame(repo, composition: comp);
      final n = await notifierFor(game.gameId);
      final ids = game.seatRowIds;
      await n.identifyRole('abominable_sectaire', [ids[0]]);
      // Ana the Sectaire shares her group with the wolf Bo and the villager Di; the other group
      // is the wolf Cy, Ed and Fi.
      await n.divideVillage({'${ids[0]}', '${ids[1]}', '${ids[3]}'});
      await n.identifyRole('loup_garou', [ids[1], ids[2]]);
      await n.applyAction(WolvesTarget(targetPlayerId: '${ids[4]}'));
      await n.applyAction(const FinalizeNight());
      await n.revealRole(ids[4], 'villageois');
      expect(stateOf(game.gameId).proposedWinner, isNull);

      await n.applyAction(DayVoteElimination(targetPlayerId: '${ids[2]}'));
      await n.applyAction(DayVoteElimination(targetPlayerId: '${ids[5]}'));

      expect(stateOf(game.gameId).engine.alivePlayers.map((p) => p.id), [
        '${ids[0]}',
        '${ids[1]}',
        '${ids[3]}',
      ]);
      expect(stateOf(game.gameId).proposedWinner, GameWinner.sectarian);
    });
  });

  group('the Wandering Judge', () {
    const comp = {'juge_begue': 1, 'loup_garou': 2, 'villageois': 3};

    Future<({int gameId, List<int> ids, GameSession n})> toVote() async {
      final game = await _startedGame(repo, composition: comp);
      final n = await notifierFor(game.gameId);
      await n.identifyRole('juge_begue', [game.seatRowIds[0]]);
      await n.identifyRole('loup_garou', [game.seatRowIds[1], game.seatRowIds[2]]);
      await n.applyAction(WolvesTarget(targetPlayerId: '${game.seatRowIds[5]}'));
      await n.applyAction(const FinalizeNight());
      await n.revealRole(game.seatRowIds[5], 'villageois');
      await n.advanceFromRecap();
      await n.electCaptain(null);
      return (gameId: game.gameId, ids: game.seatRowIds, n: n);
    }

    test('can give his sign during the first vote only, once', () async {
      final g = await toVote();
      expect(stateOf(g.gameId).day.stage, DayStage.vote);
      expect(stateOf(g.gameId).judgeCanSign, isTrue);

      await g.n.judgeSign();

      expect(stateOf(g.gameId).judgeCanSign, isFalse);
      expect(stateOf(g.gameId).engine.secondVoteToday, isTrue);
    });

    test('the first vote leads to a second, then to the end of the day', () async {
      final g = await toVote();
      await g.n.judgeSign();

      await g.n.eliminateByVote('${g.ids[3]}');
      expect(stateOf(g.gameId).day.stage, DayStage.secondVote);
      expect(stateOf(g.gameId).judgeCanSign, isFalse);

      await g.n.eliminateByVote('${g.ids[4]}');
      expect(stateOf(g.gameId).day.stage, DayStage.done);
      expect(stateOf(g.gameId).engine.alivePlayers.where((p) => !p.alive), isEmpty);
    });

    test('a first vote tied on nobody still leads to the second', () async {
      final g = await toVote();
      await g.n.judgeSign();

      await g.n.eliminateByVote(null);

      expect(stateOf(g.gameId).day.stage, DayStage.secondVote);
    });

    test('the sign is journalled, and the second vote survives a force-quit', () async {
      final g = await toVote();
      await g.n.judgeSign();
      await g.n.eliminateByVote('${g.ids[3]}');

      final log = frenchJournal(await repo.watchNightLog(g.gameId).first);
      expect(log, contains('Le Juge Bègue demande un deuxième vote'));

      final resumed = ProviderContainer(overrides: [gameRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(resumed.dispose);
      final s = await resumed.read(gameSessionProvider(g.gameId).future);
      expect(s.day.stage, DayStage.secondVote);
    });

    test('without a Judge in the game there is nothing to give', () async {
      final game = await _startedGame(repo, composition: composition);
      final s = await container.read(gameSessionProvider(game.gameId).future);
      expect(s.judgeCanSign, isFalse);
    });
  });

  group('the Scapegoat', () {
    const comp = {'bouc_emissaire': 1, 'loup_garou': 2, 'villageois': 3};

    Future<({int gameId, List<int> ids, GameSession n})> toDay() async {
      final game = await _startedGame(repo, composition: comp);
      final n = await notifierFor(game.gameId);
      await n.identifyRole('loup_garou', [game.seatRowIds[1], game.seatRowIds[2]]);
      await n.applyAction(WolvesTarget(targetPlayerId: '${game.seatRowIds[5]}'));
      await n.applyAction(const FinalizeNight());
      await n.revealRole(game.seatRowIds[5], 'villageois');
      return (gameId: game.gameId, ids: game.seatRowIds, n: n);
    }

    test('is possibly alive while his card is unknown, and known once noted', () async {
      final g = await toDay();
      expect(stateOf(g.gameId).scapegoatMayBeAlive, isTrue);
      expect(stateOf(g.gameId).knownScapegoat, isNull);

      await g.n.identifyRole('bouc_emissaire', [g.ids[0]]);

      expect(stateOf(g.gameId).scapegoatMayBeAlive, isFalse);
      expect(stateOf(g.gameId).knownScapegoat?.id, '${g.ids[0]}');
    });

    test('takes a tied vote, is journalled, and the day ends', () async {
      final g = await toDay();
      await g.n.identifyRole('bouc_emissaire', [g.ids[0]]);

      await g.n.voteTiedOnScapegoat('${g.ids[0]}');

      final s = stateOf(g.gameId);
      expect(s.engine.playerById('${g.ids[0]}').alive, isFalse);
      expect(s.day.stage, DayStage.done);
      expect(s.engine.cascade?.decision, isA<PendingScapegoatVoters>());
      final log = frenchJournal(await repo.watchNightLog(g.gameId).first);
      expect(log, contains('Égalité au vote : le Bouc Émissaire Ana est éliminé'));
    });

    test('names who votes next, which restricts the next day and is journalled', () async {
      final g = await toDay();
      await g.n.identifyRole('bouc_emissaire', [g.ids[0]]);
      await g.n.voteTiedOnScapegoat('${g.ids[0]}');

      await g.n.chooseVoters({'${g.ids[1]}', '${g.ids[3]}'});

      final s = stateOf(g.gameId);
      expect(s.engine.cascade, isNull);
      expect(s.engine.voteRestriction?.allowed, {'${g.ids[1]}', '${g.ids[3]}'});
      final log = frenchJournal(await repo.watchNightLog(g.gameId).first);
      expect(log, contains('Le Bouc Émissaire désigne qui peut voter : Bo, Di'));
    });

    test('naming nobody is journalled as such', () async {
      final g = await toDay();
      await g.n.identifyRole('bouc_emissaire', [g.ids[0]]);
      await g.n.voteTiedOnScapegoat('${g.ids[0]}');

      await g.n.chooseVoters({});

      final log = frenchJournal(await repo.watchNightLog(g.gameId).first);
      expect(log, contains('Le Bouc Émissaire ne laisse voter personne'));
    });

    test('a vote with no Scapegoat in the game is never asked about', () async {
      final game = await _startedGame(repo, composition: composition);
      final s = await container.read(gameSessionProvider(game.gameId).future);
      expect(s.scapegoatMayBeAlive, isFalse);
    });
  });

  group('the Village Idiot', () {
    const comp = {'idiot_du_village': 1, 'loup_garou': 2, 'villageois': 3};

    Future<({int gameId, List<int> ids, GameSession n})> toDay() async {
      final game = await _startedGame(repo, composition: comp);
      final n = await notifierFor(game.gameId);
      await n.identifyRole('loup_garou', [game.seatRowIds[1], game.seatRowIds[2]]);
      await n.applyAction(WolvesTarget(targetPlayerId: '${game.seatRowIds[5]}'));
      await n.applyAction(const FinalizeNight());
      await n.revealRole(game.seatRowIds[5], 'villageois');
      return (gameId: game.gameId, ids: game.seatRowIds, n: n);
    }

    test('voted against, he is pardoned, the day ends without a death, and it is journalled', () async {
      final g = await toDay();
      await g.n.identifyRole('idiot_du_village', [g.ids[0]]);

      await g.n.eliminateByVote('${g.ids[0]}');

      final s = stateOf(g.gameId);
      expect(s.engine.playerById('${g.ids[0]}').alive, isTrue);
      expect(s.engine.playerById('${g.ids[0]}').hasStatus(PlayerStatus.pardoned), isTrue);
      expect(s.day.stage, DayStage.done);
      expect(s.day.pardonedName, 'Ana');
      final log = frenchJournal(await repo.watchNightLog(g.gameId).first);
      expect(log, contains("Ana, l'Idiot du Village, est gracié par le village"));
    });

    test('the pardon note survives a force-quit', () async {
      final g = await toDay();
      await g.n.identifyRole('idiot_du_village', [g.ids[0]]);
      await g.n.eliminateByVote('${g.ids[0]}');

      final resumed = ProviderContainer(overrides: [gameRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(resumed.dispose);
      final s = await resumed.read(gameSessionProvider(g.gameId).future);

      expect(s.day.pardonedName, 'Ana');
    });

    test('is asked about while his card is unknown, and not once noted', () async {
      final g = await toDay();
      final before = stateOf(g.gameId);
      expect(before.mayBeIdiot('${g.ids[0]}'), isTrue);

      await g.n.identifyRole('idiot_du_village', [g.ids[0]]);

      expect(stateOf(g.gameId).mayBeIdiot('${g.ids[3]}'), isFalse); // the only Idiot is known
    });

    test('is never asked about when no Idiot is in the game', () async {
      final game = await _startedGame(repo, composition: composition);
      final s = await container.read(gameSessionProvider(game.gameId).future);
      expect(s.mayBeIdiot('${game.seatRowIds[0]}'), isFalse);
    });
  });

  group('the Defender', () {
    const comp = {'salvateur': 1, 'loup_garou': 2, 'villageois': 3};

    test('protects the wolves\' pick, and the journal says what happened', () async {
      final game = await _startedGame(repo, composition: comp);
      final ids = game.seatRowIds;
      final n = await notifierFor(game.gameId);
      await n.identifyRole('salvateur', [ids[0]]);
      await n.defenderProtect('${ids[3]}');
      await n.identifyRole('loup_garou', [ids[1], ids[2]]);
      await n.applyAction(WolvesTarget(targetPlayerId: '${ids[3]}'));
      await n.applyAction(const FinalizeNight());

      final s = stateOf(game.gameId);
      expect(s.engine.playerById('${ids[3]}').alive, isTrue);
      expect(s.recapDeaths, isEmpty);
      final log = frenchJournal(await repo.watchNightLog(game.gameId).first);
      expect(log, contains('Le Salvateur protège Di'));
      expect(log, contains('Di est choisi par les Loups mais protégé : personne ne meurt'));
    });

    test('is called before the wolves', () async {
      final game = await _startedGame(repo, composition: comp);
      final s = await container.read(gameSessionProvider(game.gameId).future);
      expect(s.tonight.steps.map((st) => st.role.id), ['salvateur', 'loup_garou']);
    });
  });

  group('the Angel', () {
    const comp = {'ange': 1, 'loup_garou': 2, 'villageois': 3};

    test('starts the game with a vote before night 1', () async {
      final game = await _startedGame(repo, composition: comp);
      final s = await container.read(gameSessionProvider(game.gameId).future);

      expect(s.engine.nightIndex, 0);
      expect(s.engine.phase, GamePhase.day);
      expect(s.day.stage, DayStage.vote);
      // night 1's script is already known, for the night that follows
      expect(s.tonight.steps.map((st) => st.role.id), ['loup_garou']);
    });

    test('a game without the Angel starts on night 1 as before', () async {
      final game = await _startedGame(repo, composition: composition);
      final s = await container.read(gameSessionProvider(game.gameId).future);

      expect(s.engine.nightIndex, 1);
      expect(s.engine.phase, GamePhase.night);
    });

    test('the vote, then night 1 begins', () async {
      final game = await _startedGame(repo, composition: comp);
      final n = await notifierFor(game.gameId);

      await n.eliminateByVote('${game.seatRowIds[1]}');
      expect(stateOf(game.gameId).day.stage, DayStage.done);
      await n.startNextNight();

      final s = stateOf(game.gameId);
      expect(s.engine.nightIndex, 1);
      expect(s.engine.phase, GamePhase.night);
      expect(s.cursor, SessionCursor.nightStart);
    });

    test('is proposed the win once voted out, whose card is revealed afterwards', () async {
      final game = await _startedGame(repo, composition: comp);
      final n = await notifierFor(game.gameId);

      await n.eliminateByVote('${game.seatRowIds[0]}');
      expect(stateOf(game.gameId).proposedWinner, isNull); // card not known yet
      await n.revealRole(game.seatRowIds[0], 'ange');

      expect(stateOf(game.gameId).proposedWinner, GameWinner.angel);
    });

    test('the summary of the saved game reads "before night 1"', () async {
      final game = await _startedGame(repo, composition: comp);
      await container.read(gameSessionProvider(game.gameId).future);

      final summary = await container.read(sessionSummaryProvider(game.gameId).future);
      expect(summary!.nightIndex, 0);
      expect(summary.phase, JournalPhase.day);
      expect(summary.step, SummaryStep.villageVote);
    });
  });

  group('the Piper', () {
    test('charms two players, the charmed wake right after him, and it is journalled', () async {
      final game = await _startedGame(
        repo,
        composition: {'joueur_de_flute': 1, 'loup_garou': 2, 'villageois': 3},
      );
      final ids = game.seatRowIds;
      final n = await notifierFor(game.gameId);
      await n.identifyRole('loup_garou', [ids[1], ids[2]]);
      await n.applyAction(WolvesTarget(targetPlayerId: '${ids[5]}'));
      await n.identifyRole('joueur_de_flute', [ids[0]]);

      await n.piperCharm(['${ids[3]}', '${ids[4]}']);

      final s = stateOf(game.gameId);
      expect(s.engine.playerById('${ids[3]}').hasStatus(PlayerStatus.charmed), isTrue);
      expect(s.tonight.steps.map((st) => st.role.id), ['loup_garou', 'joueur_de_flute', 'joueurs_charmes']);
      expect(s.currentStep!.role.id, 'joueurs_charmes');
      expect(s.currentStepNeedsIdentify, isFalse);
      final log = frenchJournal(await repo.watchNightLog(game.gameId).first);
      expect(log, contains('Le Joueur de Flûte charme Di et Ed'));
    });

    test('the charmed stay charmed after a force-quit, and wake the next night too', () async {
      final game = await _startedGame(
        repo,
        composition: {'joueur_de_flute': 1, 'loup_garou': 2, 'villageois': 3},
      );
      final ids = game.seatRowIds;
      final n = await notifierFor(game.gameId);
      await n.identifyRole('loup_garou', [ids[1], ids[2]]);
      await n.applyAction(WolvesTarget(targetPlayerId: '${ids[5]}'));
      await n.identifyRole('joueur_de_flute', [ids[0]]);
      await n.piperCharm(['${ids[3]}', '${ids[4]}']);
      await n.skipStep();
      await n.applyAction(const FinalizeNight());
      await n.revealRole(ids[5], 'villageois');
      await n.eliminateByVote(null);
      await n.startNextNight();

      final resumed = ProviderContainer(overrides: [gameRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(resumed.dispose);
      final s = await resumed.read(gameSessionProvider(game.gameId).future);

      expect(s.engine.playerById('${ids[4]}').hasStatus(PlayerStatus.charmed), isTrue);
      expect(s.tonight.steps.map((st) => st.role.id), ['loup_garou', 'joueur_de_flute', 'joueurs_charmes']);
    });

    test('everyone alive charmed: the Piper is proposed as the winner', () async {
      final game = await _startedGame(
        repo,
        composition: {'joueur_de_flute': 1, 'loup_garou': 2, 'villageois': 3},
      );
      final ids = game.seatRowIds;
      final n = await notifierFor(game.gameId);
      await n.identifyRole('joueur_de_flute', [ids[0]]);
      await n.applyAction(PiperCharm(playerIds: ['${ids[1]}', '${ids[2]}']));
      await n.applyAction(PiperCharm(playerIds: ['${ids[3]}', '${ids[4]}']));
      expect(stateOf(game.gameId).proposedWinner, isNull);

      await n.applyAction(PiperCharm(playerIds: ['${ids[5]}']));

      expect(stateOf(game.gameId).proposedWinner, GameWinner.piper);
    });
  });

  group('the Elder and the Knight', () {
    Future<({int gameId, List<int> ids, GameSession n})> start(Map<String, int> comp) async {
      final game = await _startedGame(repo, composition: comp);
      final n = await notifierFor(game.gameId);
      return (gameId: game.gameId, ids: game.seatRowIds, n: n);
    }

    test('the Elder survives a first bite and the journal says so', () async {
      final g = await start({'ancien': 1, 'loup_garou': 2, 'villageois': 3});
      await g.n.identifyRole('ancien', [g.ids[0]]); // Ana, noted when the wolves picked her
      await g.n.identifyRole('loup_garou', [g.ids[1], g.ids[2]]);
      await g.n.applyAction(WolvesTarget(targetPlayerId: '${g.ids[0]}'));
      await g.n.applyAction(const FinalizeNight());

      final s = stateOf(g.gameId);
      expect(s.engine.playerById('${g.ids[0]}').alive, isTrue);
      expect(s.recapDeaths, isEmpty);
      final log = frenchJournal(await repo.watchNightLog(g.gameId).first);
      expect(log, contains("Ana, l'Ancien, survit à la morsure"));
    });

    test('the Elder voted out costs the villagers their powers: the next night skips them', () async {
      final g = await start({'ancien': 1, 'voyante': 1, 'loup_garou': 2, 'villageois': 2});
      await g.n.identifyRole('ancien', [g.ids[0]]);
      await g.n.identifyRole('voyante', [g.ids[1]]);
      await g.n.skipStep();
      await g.n.identifyRole('loup_garou', [g.ids[2], g.ids[3]]);
      await g.n.applyAction(WolvesTarget(targetPlayerId: '${g.ids[4]}'));
      await g.n.applyAction(const FinalizeNight());
      await g.n.revealRole(g.ids[4], 'villageois');
      await g.n.eliminateByVote('${g.ids[0]}');

      expect(stateOf(g.gameId).engine.villagersPowerless, isTrue);
      final log = frenchJournal(await repo.watchNightLog(g.gameId).first);
      expect(log, contains("Ana, l'Ancien, est éliminé : les villageois perdent leurs pouvoirs"));

      await g.n.startNextNight();
      expect(stateOf(g.gameId).tonight.steps.map((st) => st.role.id), ['loup_garou']);
    });

    test('a devoured Knight asks which wolf is diseased, and that wolf dies as the night begins', () async {
      final g = await start({'chevalier': 1, 'loup_garou': 2, 'villageois': 3});
      await g.n.identifyRole('loup_garou', [g.ids[2], g.ids[4]]); // Cy and Ed
      await g.n.applyAction(WolvesTarget(targetPlayerId: '${g.ids[0]}')); // Ana, the Knight
      await g.n.applyAction(const FinalizeNight());
      await g.n.revealRole(g.ids[0], 'chevalier');

      expect(stateOf(g.gameId).engine.cascade?.decision, isA<PendingKnightWound>());
      await g.n.knightContaminate('${g.ids[4]}'); // Ed
      expect(stateOf(g.gameId).engine.cascade, isNull);
      expect(stateOf(g.gameId).engine.knightWound?.wolfId, '${g.ids[4]}');

      await g.n.eliminateByVote(null);
      await g.n.startNextNight();

      final s = stateOf(g.gameId);
      expect(s.engine.playerById('${g.ids[4]}').alive, isFalse);
      expect(s.engine.playerById('${g.ids[4]}').causeOfDeath, isA<DiseaseKill>());
      final log = frenchJournal(await repo.watchNightLog(g.gameId).first);
      expect(log, containsAll(['Le Chevalier laisse Ed malade', 'Ed meurt de la maladie du Chevalier']));
    });

    test('the wolf is spared when the MJ finds none to wound', () async {
      final g = await start({'chevalier': 1, 'loup_garou': 2, 'villageois': 3});
      await g.n.identifyRole('loup_garou', [g.ids[2], g.ids[4]]);
      await g.n.applyAction(WolvesTarget(targetPlayerId: '${g.ids[0]}'));
      await g.n.applyAction(const FinalizeNight());
      await g.n.revealRole(g.ids[0], 'chevalier');

      await g.n.knightContaminate(null);

      expect(stateOf(g.gameId).engine.knightWound, isNull);
    });
  });

  group('the wolf camp', () {
    Future<({int gameId, List<int> ids, GameSession n})> start(Map<String, int> comp) async {
      final game = await _startedGame(repo, composition: comp);
      final n = await notifierFor(game.gameId);
      return (gameId: game.gameId, ids: game.seatRowIds, n: n);
    }

    test('the Cursed Wolf-Father infects the victim, who lives on as a wolf', () async {
      final g = await start({'infect_pere_des_loups': 1, 'loup_garou': 2, 'villageois': 3});
      await g.n.identifyRole('loup_garou', [g.ids[0], g.ids[1]]);
      await g.n.applyAction(WolvesTarget(targetPlayerId: '${g.ids[3]}'));
      await g.n.identifyRole('infect_pere_des_loups', [g.ids[2]]);

      await g.n.infectVictim();
      await g.n.applyAction(const FinalizeNight());

      final s = stateOf(g.gameId);
      final di = s.engine.playerById('${g.ids[3]}');
      expect(di.alive, isTrue);
      expect(di.teamOverride, Team.werewolves);
      expect(s.engine.spentPowers, {'infect_pere_des_loups': 1});
      final log = frenchJournal(await repo.watchNightLog(g.gameId).first);
      expect(log, contains("Di est infecté par l'Infect Père des Loups"));
    });

    test('the next night no longer calls him, once he has infected', () async {
      final g = await start({'infect_pere_des_loups': 1, 'loup_garou': 2, 'villageois': 3});
      await g.n.identifyRole('loup_garou', [g.ids[0], g.ids[1]]);
      await g.n.applyAction(WolvesTarget(targetPlayerId: '${g.ids[3]}'));
      await g.n.identifyRole('infect_pere_des_loups', [g.ids[2]]);
      await g.n.infectVictim();
      await g.n.applyAction(const FinalizeNight());
      await g.n.startNextNight();

      expect(stateOf(g.gameId).tonight.steps.map((st) => st.role.id), ['loup_garou']);
    });

    test('the Big Bad Wolf\'s second victim dies with the first, and he stops once a wolf dies', () async {
      final g = await start({'grand_mechant_loup': 1, 'loup_garou': 2, 'villageois': 3});
      await g.n.identifyRole('loup_garou', [g.ids[0], g.ids[1]]);
      await g.n.applyAction(WolvesTarget(targetPlayerId: '${g.ids[3]}'));
      await g.n.identifyRole('grand_mechant_loup', [g.ids[2]]);
      await g.n.bigBadWolfTarget('${g.ids[4]}');
      await g.n.applyAction(const FinalizeNight());

      final s = stateOf(g.gameId);
      expect(s.engine.playerById('${g.ids[3]}').alive, isFalse);
      expect(s.engine.playerById('${g.ids[4]}').alive, isFalse);
      final log = frenchJournal(await repo.watchNightLog(g.gameId).first);
      expect(log, contains('Le Grand-Méchant-Loup dévore aussi Ed'));
    });

    test('a Wolf-Hound who chooses the wolves is on their side, and it is journalled', () async {
      final g = await start({'chien_loup': 1, 'loup_garou': 2, 'villageois': 3});
      await g.n.identifyRole('chien_loup', [g.ids[0]]);

      await g.n.chienLoupChoose(engineId: '${g.ids[0]}', wolf: true);

      final s = stateOf(g.gameId);
      expect(s.engine.playerById('${g.ids[0]}').teamOverride, Team.werewolves);
      expect(s.currentStep!.role.id, 'loup_garou');
      final log = frenchJournal(await repo.watchNightLog(g.gameId).first);
      expect(log, contains('Ana, Chien-Loup, rejoint les Loups'));
    });

    test('the Wild Child\'s model is kept and journalled', () async {
      final g = await start({'enfant_sauvage': 1, 'loup_garou': 2, 'villageois': 3});
      await g.n.identifyRole('enfant_sauvage', [g.ids[0]]);

      await g.n.wildChildChoose(childEngineId: '${g.ids[0]}', modelEngineId: '${g.ids[2]}');

      expect(stateOf(g.gameId).engine.wildChild?.modelId, '${g.ids[2]}');
      final log = frenchJournal(await repo.watchNightLog(g.gameId).first);
      expect(log, contains('Ana prend Cy pour modèle'));
    });

    test('the White Werewolf is identified on night 1 and used from night 2', () async {
      final g = await start({'loup_garou_blanc': 1, 'loup_garou': 2, 'villageois': 3});
      expect(stateOf(g.gameId).tonight.steps.map((st) => (st.role.id, st.identifyOnly)), [
        ('loup_garou', false),
        ('loup_garou_blanc', true),
      ]);

      await g.n.identifyRole('loup_garou', [g.ids[0], g.ids[1]]);
      await g.n.applyAction(WolvesTarget(targetPlayerId: '${g.ids[3]}'));
      await g.n.identifyRole('loup_garou_blanc', [g.ids[2]]);
      await g.n.skipStep();
      await g.n.applyAction(const FinalizeNight());
      await g.n.startNextNight();

      expect(
        stateOf(g.gameId).tonight.steps.map((st) => (st.role.id, st.identifyOnly)),
        [('loup_garou', false), ('loup_garou_blanc', false)],
      );
    });
  });

  group('the place of the Fox in the order', () {
    const comp = {'renard': 1, 'voyante': 1, 'sorciere': 1, 'loup_garou': 2, 'villageois': 1};

    ProviderContainer containerWith({required bool foxAfterWitch}) {
      SharedPreferences.setMockInitialValues({'fox_after_witch': foxAfterWitch});
      return ProviderContainer(
        overrides: [
          gameRepositoryProvider.overrideWithValue(repo),
          sharedPreferencesProvider.overrideWith((ref) async => SharedPreferences.getInstance()),
        ],
      );
    }

    test('follows the setting when the game starts, and keeps it afterwards', () async {
      final game = await _startedGame(repo, composition: comp);
      final first = containerWith(foxAfterWitch: true);
      addTearDown(first.dispose);
      await first.read(settingsProvider.future);
      var s = await first.read(gameSessionProvider(game.gameId).future);
      expect(s.tonight.steps.map((st) => st.role.id), ['voyante', 'loup_garou', 'sorciere', 'renard']);

      // The MJ flips the setting back: this game keeps its order.
      final later = containerWith(foxAfterWitch: false);
      addTearDown(later.dispose);
      await later.read(settingsProvider.future);
      s = await later.read(gameSessionProvider(game.gameId).future);
      expect(s.tonight.steps.map((st) => st.role.id), ['voyante', 'loup_garou', 'sorciere', 'renard']);
    });

    test('is after the Voyante by default', () async {
      final game = await _startedGame(repo, composition: comp);
      final s = await container.read(gameSessionProvider(game.gameId).future);
      expect(s.tonight.steps.map((st) => st.role.id), ['voyante', 'renard', 'loup_garou', 'sorciere']);
    });
  });

  test('the White Werewolf parity follows the setting when the game starts and is kept', () async {
    const comp = {'loup_garou_blanc': 1, 'loup_garou': 2, 'villageois': 3};
    final game = await _startedGame(repo, composition: comp);
    SharedPreferences.setMockInitialValues({'white_wolf_odd_nights': true});
    final odd = ProviderContainer(
      overrides: [
        gameRepositoryProvider.overrideWithValue(repo),
        sharedPreferencesProvider.overrideWith((ref) async => SharedPreferences.getInstance()),
      ],
    );
    addTearDown(odd.dispose);
    await odd.read(settingsProvider.future);

    var s = await odd.read(gameSessionProvider(game.gameId).future);
    // On night 1 his solo power is on: no longer a step that only identifies him.
    expect(s.tonight.steps.map((st) => (st.role.id, st.identifyOnly)), [
      ('loup_garou', false),
      ('loup_garou_blanc', false),
    ]);

    // Another session of the same game, with the setting back off: the game keeps its parity.
    SharedPreferences.setMockInitialValues({});
    final later = ProviderContainer(overrides: [gameRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(later.dispose);
    s = await later.read(gameSessionProvider(game.gameId).future);
    expect(s.whiteWolfOddNights, isTrue);
  });

  group('the Fox', () {
    // 6 players: Ana the Fox, Bo and Cy wolves, the rest villagers; seats in roster order.
    const comp = {'renard': 1, 'loup_garou': 2, 'villageois': 3};

    Future<({int gameId, List<int> ids, GameSession n})> startedAsFox() async {
      final game = await _startedGame(repo, composition: comp);
      final n = await notifierFor(game.gameId);
      await n.identifyRole('renard', [game.seatRowIds[0]]); // Ana
      return (gameId: game.gameId, ids: game.seatRowIds, n: n);
    }

    test('a sniff that finds a wolf keeps his power, and journals it', () async {
      final f = await startedAsFox();

      await f.n.foxSniff(middleEngineId: '${f.ids[2]}', wolfFound: true);

      final s = stateOf(f.gameId);
      expect(s.engine.spentPowers, isEmpty);
      expect(s.currentStep!.role.id, 'loup_garou'); // moved on
      final log = frenchJournal(await repo.watchNightLog(f.gameId).first);
      expect(log, contains('Le Renard flaire autour de Cy : un Loup'));
    });

    test('a sniff that finds none ends his power for the rest of the game', () async {
      final f = await startedAsFox();

      await f.n.foxSniff(middleEngineId: '${f.ids[4]}', wolfFound: false);

      final s = stateOf(f.gameId);
      expect(s.engine.spentPowers, {'renard': 1});
      final log = frenchJournal(await repo.watchNightLog(f.gameId).first);
      expect(log, contains('Le Renard flaire autour de Ed : aucun Loup, il perd son pouvoir'));
    });

    test('the lost power survives a force-quit', () async {
      final f = await startedAsFox();
      await f.n.foxSniff(middleEngineId: '${f.ids[4]}', wolfFound: false);

      final resumed = ProviderContainer(
        overrides: [gameRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(resumed.dispose);
      final s = await resumed.read(gameSessionProvider(f.gameId).future);

      expect(s.engine.spentPowers, {'renard': 1});
    });
  });

  test('the Two Sisters meeting is journalled and moves on', () async {
    final game = await _startedGame(
      repo,
      composition: const {'deux_soeurs': 2, 'loup_garou': 2, 'villageois': 2},
    );
    final n = await notifierFor(game.gameId);
    await n.identifyRole('deux_soeurs', [game.seatRowIds[0], game.seatRowIds[1]]);

    await n.sistersMet();

    expect(stateOf(game.gameId).currentStep!.role.id, 'loup_garou');
    final log = frenchJournal(await repo.watchNightLog(game.gameId).first);
    expect(log, contains('Les Deux Sœurs se reconnaissent'));
  });

  test('the Three Brothers meeting is journalled and moves on', () async {
    final game = await _startedGame(
      repo,
      composition: const {'trois_freres': 3, 'loup_garou': 2, 'villageois': 1},
    );
    final n = await notifierFor(game.gameId);
    await n.identifyRole('trois_freres', [
      game.seatRowIds[0],
      game.seatRowIds[1],
      game.seatRowIds[2],
    ]);

    await n.brothersMet();

    expect(stateOf(game.gameId).currentStep!.role.id, 'loup_garou');
    final log = frenchJournal(await repo.watchNightLog(game.gameId).first);
    expect(log, contains('Les Trois Frères se reconnaissent'));
  });

  group('a drawn Voleur reserve', () {
    // 6 players; the pack holds 2 more Simples Villageois than that.
    const comp = {'voleur': 1, 'loup_garou': 2, 'sorciere': 1, 'villageois': 2};

    test('is asked for at the Voleur step, and calls every role of the composition', () async {
      final game = await _startedGame(repo, composition: comp);
      final s = (await container.read(gameSessionProvider(game.gameId).future));

      expect(s.reserveDrawn, isTrue);
      expect(s.reserveToEnter, isTrue);
      expect(s.reserveRoleIds, isEmpty);
      expect(s.tonight.steps.map((st) => st.role.id), ['voleur', 'loup_garou', 'sorciere']);
      // The pack: the composition plus two Simples Villageois.
      expect({for (final c in s.pack) c.roleId: c.count}, {
        'voleur': 1,
        'loup_garou': 2,
        'sorciere': 1,
        'villageois': 4,
      });
    });

    test('a reserve picked at composition is not drawn', () async {
      final game = await _startedGame(
        repo,
        composition: comp,
        reserveRoleIds: const ['voyante', 'chasseur'],
      );
      final s = await container.read(gameSessionProvider(game.gameId).future);

      expect(s.reserveDrawn, isFalse);
      expect(s.reserveToEnter, isFalse);
      expect(s.dealtComposition, comp);
      expect(s.expectedHolders('loup_garou'), 2);
    });

    test('a game with no Voleur has no reserve to draw', () async {
      final game = await _startedGame(repo, composition: composition);
      final s = await container.read(gameSessionProvider(game.gameId).future);

      expect(s.reserveDrawn, isFalse);
    });

    test('noting the two cards takes them out of the roles that can have a holder', () async {
      final game = await _startedGame(repo, composition: comp);
      final n = await notifierFor(game.gameId);

      await n.enterReserve(const ['sorciere', 'villageois']);

      final s = stateOf(game.gameId);
      expect(s.reserveRoleIds, ['sorciere', 'villageois']);
      expect(s.reserveToEnter, isFalse);
      expect(s.dealtComposition, {'voleur': 1, 'loup_garou': 2, 'villageois': 3});
      expect(s.expectedHolders('sorciere'), 0);
      // The script still calls the Sorcière: her card is in the middle, the MJ bluffs.
      expect(s.tonight.steps.map((st) => st.role.id), ['voleur', 'loup_garou', 'sorciere']);
    });

    test('is remembered across a force-quit', () async {
      final game = await _startedGame(repo, composition: comp);
      final n = await notifierFor(game.gameId);
      await n.enterReserve(const ['sorciere', 'villageois']);

      final resumed = ProviderContainer(
        overrides: [gameRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(resumed.dispose);
      final s = await resumed.read(gameSessionProvider(game.gameId).future);

      expect(s.reserveRoleIds, ['sorciere', 'villageois']);
      expect(s.reserveToEnter, isFalse);
      // It lives in the session, not in the game's own reserve column.
      expect((await repo.getGame(game.gameId))!.reserveRolesJson, isNull);
    });

    test('refuses a reserve that is not two cards, or noted twice', () async {
      final game = await _startedGame(repo, composition: comp);
      final n = await notifierFor(game.gameId);

      await n.enterReserve(const ['sorciere']);
      expect(stateOf(game.gameId).reserveToEnter, isTrue);

      await n.enterReserve(const ['sorciere', 'villageois']);
      await n.enterReserve(const ['loup_garou', 'loup_garou']);
      expect(stateOf(game.gameId).reserveRoleIds, ['sorciere', 'villageois']);
    });

    test('a Voleur card left in the middle means nobody holds the Voleur', () async {
      final game = await _startedGame(repo, composition: comp);
      final n = await notifierFor(game.gameId);

      await n.enterReserve(const ['voleur', 'villageois']);

      final s = stateOf(game.gameId);
      expect(s.expectedHolders('voleur'), 0);
      expect(s.currentStepNeedsIdentify, isFalse); // straight to the (empty) act
    });

    test('stealing a card whose role has no other holder needs no identification', () async {
      final game = await _startedGame(repo, composition: comp);
      final ids = game.seatRowIds;
      final n = await notifierFor(game.gameId);
      await n.enterReserve(const ['sorciere', 'villageois']);

      await n.identifyRole('voleur', [ids[0]]); // Voleur = Ana
      await n.voleurSwap(voleurEngineId: '${ids[0]}', stolenRoleId: 'sorciere');

      final s = stateOf(game.gameId);
      expect(s.engine.playerById('${ids[0]}').roleId, 'sorciere');
      expect(s.dealtHoldersKnown('sorciere'), 0); // the stolen card is a bonus
      expect(s.currentStep!.role.id, 'loup_garou');
    });

    test('two wolves in the reserve force the swap: keeping his card is refused', () async {
      final game = await _startedGame(repo, composition: comp);
      final ids = game.seatRowIds;
      final n = await notifierFor(game.gameId);
      await n.enterReserve(const ['loup_garou', 'loup_garou']);
      await n.identifyRole('voleur', [ids[0]]);

      expect(stateOf(game.gameId).reserveForcesSwap, isTrue);
      await n.voleurSwap(voleurEngineId: '${ids[0]}', stolenRoleId: null);
      expect(stateOf(game.gameId).cursor.stepIndex, 0); // still on the Voleur's step
      expect(stateOf(game.gameId).engine.playerById('${ids[0]}').roleId, 'voleur');

      await n.voleurSwap(voleurEngineId: '${ids[0]}', stolenRoleId: 'loup_garou');
      expect(stateOf(game.gameId).engine.playerById('${ids[0]}').roleId, 'loup_garou');
    });

    test('one wolf and another card leave the choice open', () async {
      final game = await _startedGame(repo, composition: comp);
      final n = await notifierFor(game.gameId);

      await n.enterReserve(const ['loup_garou', 'villageois']);

      expect(stateOf(game.gameId).reserveForcesSwap, isFalse);
    });

    test('the roles a reveal can name are the cards that were really dealt', () async {
      final game = await _startedGame(repo, composition: comp);
      final n = await notifierFor(game.gameId);
      await n.enterReserve(const ['sorciere', 'villageois']);

      expect(
        {for (final r in unassignedRoles(stateOf(game.gameId))) r.roleId: r.remaining},
        {'voleur': 1, 'loup_garou': 2, 'villageois': 3},
      );
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
