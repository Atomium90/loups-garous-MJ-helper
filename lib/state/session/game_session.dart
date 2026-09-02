import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../data/database/app_database.dart';
import '../../data/models/night_log_entry.dart';
import '../../data/repositories/game_not_found_exception.dart';
import '../providers/game_repository_provider.dart';
import 'night_log_entry.dart';
import 'night_script.dart';
import 'session_cursor.dart';

part 'game_session.g.dart';

/// The interrupt that must be cleared before the current [DayStage] body shows:
/// a dead player's card to reveal, a chain effect to resolve, or a lover's
/// grief death to acknowledge. Priority order, highest first.
enum DayInterrupt { reveal, chain, loversAck }

/// Everything a running game's screens read: the engine truth, where we are in
/// tonight's script and in the day, that script, the composition it was built
/// from, and the roster (the source of truth for which cards are confirmed).
class GameSessionState {
  final GameState engine;
  final SessionCursor cursor;
  final DaySnapshot day;
  final NightScript tonight;
  final Map<String, int> composition;
  final List<PlayerRow> roster;

  const GameSessionState({
    required this.engine,
    required this.cursor,
    required this.day,
    required this.tonight,
    required this.composition,
    required this.roster,
  });

  /// The step the cursor points at, or null once every step is done (the
  /// "ready to resolve the night" state).
  NightScriptStep? get currentStep =>
      cursor.stepIndex < tonight.steps.length ? tonight.steps[cursor.stepIndex] : null;

  bool get readyToResolve =>
      engine.phase == GamePhase.night && cursor.stepIndex >= tonight.steps.length;

  /// The deaths the J1 recap reads aloud: everyone who died in the night just
  /// resolved. Engine-derived (each `Player` carries its cause and timing), so
  /// it survives a force-quit onto the recap.
  List<Player> get recapDeaths => engine.players
      .where(
        (p) => !p.alive && p.diedOnNight == engine.nightIndex && p.diedOnPhase == GamePhase.night,
      )
      .toList(growable: false);

  /// Dead players whose card was never recorded (roster `roleId` still null) -
  /// each gets the reveal panel before the day can proceed.
  List<Player> get unrevealedDead {
    final unknown = {
      for (final r in roster)
        if (r.roleId == null) '${r.id}',
    };
    return engine.players
        .where((p) => !p.alive && unknown.contains(p.id))
        .toList(growable: false);
  }

  DayInterrupt? get dayInterrupt {
    if (unrevealedDead.isNotEmpty) return DayInterrupt.reveal;
    if (engine.cascade != null) return DayInterrupt.chain;
    if (day.loversAck.isNotEmpty) return DayInterrupt.loversAck;
    return null;
  }
}

/// The orchestrator: loads-or-seeds a game's `GameState`, applies MJ-reported
/// facts through the pure `GameStateMachine`, and persists a snapshot after
/// every change so a force-quit resumes on the exact step - including mid
/// death-cascade.
///
/// Night role identification (the blind deal) edits the engine players' roleId
/// directly; a post-mortem reveal goes through the engine's `RevealRole` so it
/// can replay the dead player's on-death effect. Un-identified players carry a
/// `villageois` placeholder in the engine; the roster's null `roleId` is the
/// real "not known yet" signal.
@riverpod
class GameSession extends _$GameSession {
  static const _placeholderRole = 'villageois';
  static const _machine = GameStateMachine();
  final _registry = RoleRegistry.base;

  @override
  Future<GameSessionState> build(int gameId) async {
    final repo = ref.read(gameRepositoryProvider);
    final game = await repo.getGame(gameId);
    if (game == null) throw GameNotFoundException(gameId);
    final composition = game.compositionJson ?? const <String, int>{};
    final roster = await repo.getRoster(gameId);

    final GameState engine;
    final SessionCursor cursor;
    final DaySnapshot day;
    final existing = game.sessionJson;
    if (existing == null) {
      engine = GameState.initial(
        players: [
          for (final r in roster)
            Player(id: '${r.id}', name: r.name, roleId: r.roleId ?? _placeholderRole),
        ],
      );
      cursor = SessionCursor.nightStart;
      day = DaySnapshot.fresh;
      await _persist(engine, cursor, day);
    } else {
      final decoded = jsonDecode(existing) as Map<String, dynamic>;
      engine = GameStateJson.decode(decoded['engine'] as Map<String, dynamic>);
      cursor = SessionCursor.fromJson(decoded['cursor'] as Map<String, dynamic>);
      day = decoded['day'] == null
          ? DaySnapshot.fresh
          : DaySnapshot.fromJson(decoded['day'] as Map<String, dynamic>);
    }

    final tonight = buildNightScript(engine: engine, composition: composition);
    return GameSessionState(
      engine: engine,
      cursor: _clamp(cursor, tonight),
      day: day,
      tonight: tonight,
      composition: composition,
      roster: roster,
    );
  }

  Future<void> _persist(GameState engine, SessionCursor cursor, DaySnapshot day) {
    final blob = jsonEncode({
      'engine': GameStateJson.encode(engine),
      'cursor': cursor.toJson(),
      'day': day.toJson(),
    });
    return ref.read(gameRepositoryProvider).saveSession(gameId: gameId, sessionJson: blob);
  }

  Future<List<PlayerRow>> _loadRoster() =>
      ref.read(gameRepositoryProvider).getRoster(gameId);

  SessionCursor _clamp(SessionCursor c, NightScript script) => c.stepIndex <= script.steps.length
      ? c
      : SessionCursor(stepIndex: script.steps.length, subStep: NightSubStep.act);

  String _phaseLabel(GameState s) =>
      s.phase == GamePhase.night ? 'NUIT ${s.nightIndex}' : 'JOUR ${s.nightIndex}';

  // --- night: identification ---

  /// Record who holds [roleId] (the N1 identification step) and move on to its
  /// action.
  Future<void> identifyRole(String roleId, List<int> playerRowIds) async {
    final s = state.value;
    if (s == null) return;
    await ref.read(gameRepositoryProvider).assignRoles(
      playerRowIds: playerRowIds,
      roleId: roleId,
    );
    final ids = {for (final i in playerRowIds) '$i'};
    final engine = s.engine.copyWith(
      players: [
        for (final p in s.engine.players)
          if (ids.contains(p.id)) p.copyWith(roleId: roleId) else p,
      ],
    );
    final cursor = s.cursor.copyWith(subStep: NightSubStep.act);
    final roster = await _loadRoster();
    await _persist(engine, cursor, s.day);
    _emit(s, engine: engine, cursor: cursor, roster: roster);
  }

  /// Advance past the current step with no engine action - "Je noterai plus
  /// tard" during identify, "Passer ce rôle" / "Continuer" during a role's act,
  /// or "Terminer" once the Witch is done.
  Future<void> skipStep() async {
    final s = state.value;
    if (s == null) return;
    final cursor = SessionCursor(
      stepIndex: s.cursor.stepIndex + 1,
      subStep: NightSubStep.identify,
    );
    await _persist(s.engine, cursor, s.day);
    _emit(s, cursor: cursor);
  }

  // --- night: Cupidon ---

  Future<void> pairLovers(String engineIdA, String engineIdB) =>
      applyAction(CupidonPair(playerAId: engineIdA, playerBId: engineIdB));

  // --- day: recap CTA ---

  /// The J1 recap's forward button: day 1 offers the captain election first,
  /// day 2+ goes straight to the vote.
  Future<void> advanceFromRecap() async {
    final s = state.value;
    if (s == null) return;
    final next = s.engine.nightIndex == 1 && s.engine.captainPlayerId == null
        ? DayStage.captain
        : DayStage.vote;
    await _updateDay((d) => d.copyWith(stage: next));
  }

  // --- day: captain election (J2) ---

  Future<void> electCaptain(String? engineId) async {
    if (engineId != null) {
      await applyAction(ElectCaptain(playerId: engineId));
    } else {
      await _updateDay((d) => d.copyWith(stage: DayStage.vote));
    }
  }

  // --- day: village vote (J3) ---

  Future<void> eliminateByVote(String? engineId) async {
    if (engineId != null) {
      await applyAction(DayVoteElimination(targetPlayerId: engineId));
      return;
    }
    final s = state.value;
    if (s == null) return;
    await ref.read(gameRepositoryProvider).appendNightLog(
      gameId: gameId,
      entries: [
        NightLogEntry(
          phaseLabel: _phaseLabel(s.engine),
          iconName: 'scale',
          line: "Égalité, personne n'est éliminé",
        ),
      ],
    );
    await _updateDay((d) => d.copyWith(stage: DayStage.done));
  }

  // --- day: the interrupts (reveal / chain / grief) ---

  /// Post-mortem card reveal (the reveal panel).
  Future<void> revealRole(int rowId, String roleId) async {
    await ref.read(gameRepositoryProvider).assignRoles(playerRowIds: [rowId], roleId: roleId);
    await applyAction(RevealRole(playerId: '$rowId', roleId: roleId));
  }

  Future<void> hunterShoot(String? engineId) =>
      applyAction(HunterShoot(targetPlayerId: engineId));

  Future<void> nameCaptainSuccessor(String engineId) =>
      applyAction(CaptainNameSuccessor(successorPlayerId: engineId));

  Future<void> acknowledgeLoversDeaths() =>
      _updateDay((d) => d.copyWith(loversAck: const []));

  // --- day -> next night ---

  Future<void> startNextNight() async {
    final s = state.value;
    if (s == null) return;
    final result = _machine.apply(
      state: s.engine,
      action: const StartNextNight(),
      roleRegistry: _registry,
    );
    const cursor = SessionCursor.nightStart;
    const day = DaySnapshot.fresh;
    await _persist(result.state, cursor, day);
    _emit(s, engine: result.state, cursor: cursor, day: day);
  }

  // --- the engine-action pipeline ---

  /// Report an MJ fact to the engine, journal what it produced, fold any
  /// day-state change in, and persist.
  Future<void> applyAction(GameAction action) async {
    final s = state.value;
    if (s == null) return;
    final result = _machine.apply(state: s.engine, action: action, roleRegistry: _registry);

    final lines = <NightLogEntry>[
      ...nightLogEntriesFor(action, s.engine),
      for (final e in result.events)
        if (e is PlayerDied && e.cause is LoversCascadeKill)
          NightLogEntry(
            phaseLabel: _phaseLabel(result.state),
            iconName: 'skull',
            line: '${s.engine.playerById(e.playerId).name} meurt de chagrin',
          ),
    ];
    if (lines.isNotEmpty) {
      await ref.read(gameRepositoryProvider).appendNightLog(gameId: gameId, entries: lines);
    }

    final cursor = _cursorAfter(action, s.cursor);
    final day = _dayAfter(action, result, s);
    final roster = action is RevealRole ? await _loadRoster() : s.roster;

    await _persist(result.state, cursor, day);
    _emit(s, engine: result.state, cursor: cursor, day: day, roster: roster);
  }

  DaySnapshot _dayAfter(GameAction action, ActionResult result, GameSessionState s) {
    var day = s.day;

    final victimId = s.engine.pendingWolfVictimId;
    if (action is WitchLifePotion && victimId != null) {
      day = day.copyWith(savedFromWolvesName: s.engine.playerById(victimId).name);
    }

    final griefDeaths = [
      for (final e in result.events)
        if (e is PlayerDied && e.cause is LoversCascadeKill) e.playerId,
    ];
    if (griefDeaths.isNotEmpty) {
      day = day.copyWith(loversAck: [...day.loversAck, ...griefDeaths]);
    }

    if (action is ElectCaptain) day = day.copyWith(stage: DayStage.vote);
    if (action is DayVoteElimination) day = day.copyWith(stage: DayStage.done);

    return day;
  }

  SessionCursor _cursorAfter(GameAction action, SessionCursor c) => switch (action) {
    // These complete a night role's turn -> advance to the next step.
    WolvesTarget() || CupidonPair() || VoleurSwap() => SessionCursor(
      stepIndex: c.stepIndex + 1,
      subStep: NightSubStep.identify,
    ),
    // The Witch's turn spans several taps, FinalizeNight flips the phase, and
    // every day action leaves the night cursor untouched.
    _ => c,
  };

  Future<void> _updateDay(DaySnapshot Function(DaySnapshot) f) async {
    final s = state.value;
    if (s == null) return;
    final day = f(s.day);
    await _persist(s.engine, s.cursor, day);
    _emit(s, day: day);
  }

  void _emit(
    GameSessionState prev, {
    GameState? engine,
    SessionCursor? cursor,
    DaySnapshot? day,
    List<PlayerRow>? roster,
  }) {
    final nextEngine = engine ?? prev.engine;
    state = AsyncData(
      GameSessionState(
        engine: nextEngine,
        cursor: cursor ?? prev.cursor,
        day: day ?? prev.day,
        tonight: buildNightScript(engine: nextEngine, composition: prev.composition),
        composition: prev.composition,
        roster: roster ?? prev.roster,
      ),
    );
  }
}
