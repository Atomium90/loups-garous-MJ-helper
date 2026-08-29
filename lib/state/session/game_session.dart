import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../data/repositories/game_not_found_exception.dart';
import '../providers/game_repository_provider.dart';
import 'night_log_entry.dart';
import 'night_script.dart';
import 'session_cursor.dart';

part 'game_session.g.dart';

/// A death the most recent `FinalizeNight` produced - held in memory for the
/// day recap, not persisted (the recap is only reached right after resolving).
class ResolvedDeath {
  final String playerId;
  final DeathCause cause;
  const ResolvedDeath(this.playerId, this.cause);
}

/// Everything a running game's screens read: the engine truth, where we are in
/// tonight's script, that script itself, and the composition it was built from.
class GameSessionState {
  final GameState engine;
  final SessionCursor cursor;
  final NightScript tonight;
  final Map<String, int> composition;
  final List<ResolvedDeath> lastResolution;

  const GameSessionState({
    required this.engine,
    required this.cursor,
    required this.tonight,
    required this.composition,
    this.lastResolution = const [],
  });

  /// The step the cursor points at, or null once every step is done (the
  /// "ready to resolve the night" state).
  NightScriptStep? get currentStep =>
      cursor.stepIndex < tonight.steps.length ? tonight.steps[cursor.stepIndex] : null;

  bool get readyToResolve =>
      engine.phase == GamePhase.night && cursor.stepIndex >= tonight.steps.length;
}

/// The orchestrator: loads-or-seeds a game's `GameState`, applies MJ-reported
/// facts through the pure `GameStateMachine`, and persists a snapshot after
/// every change so a force-quit resumes on the exact step.
///
/// Role identification (the blind deal) is not an engine action - it edits the
/// engine players' `roleId` directly between calls. Un-identified players carry
/// a `villageois` placeholder in the engine; the roster's `roleId` staying null
/// is the real "not known yet" signal.
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

    final GameState engine;
    final SessionCursor cursor;
    final existing = game.sessionJson;
    if (existing == null) {
      final roster = await repo.getRoster(gameId);
      engine = GameState.initial(
        players: [
          for (final r in roster)
            Player(id: '${r.id}', name: r.name, roleId: r.roleId ?? _placeholderRole),
        ],
      );
      cursor = SessionCursor.nightStart;
      await _persist(engine, cursor);
    } else {
      final decoded = jsonDecode(existing) as Map<String, dynamic>;
      engine = GameStateJson.decode(decoded['engine'] as Map<String, dynamic>);
      cursor = SessionCursor.fromJson(decoded['cursor'] as Map<String, dynamic>);
    }

    final tonight = buildNightScript(engine: engine, composition: composition);
    return GameSessionState(
      engine: engine,
      cursor: _clamp(cursor, tonight),
      tonight: tonight,
      composition: composition,
    );
  }

  Future<void> _persist(GameState engine, SessionCursor cursor) {
    final blob = jsonEncode({
      'engine': GameStateJson.encode(engine),
      'cursor': cursor.toJson(),
    });
    return ref.read(gameRepositoryProvider).saveSession(gameId: gameId, sessionJson: blob);
  }

  SessionCursor _clamp(SessionCursor c, NightScript script) => c.stepIndex <= script.steps.length
      ? c
      : SessionCursor(stepIndex: script.steps.length, subStep: NightSubStep.act);

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
    await _persist(engine, cursor);
    _emit(s, engine: engine, cursor: cursor);
  }

  /// Report an MJ fact to the engine, journal what it produced, persist.
  Future<void> applyAction(GameAction action) async {
    final s = state.value;
    if (s == null) return;
    final result = _machine.apply(state: s.engine, action: action, roleRegistry: _registry);

    final lines = nightLogEntriesFor(action, s.engine);
    if (lines.isNotEmpty) {
      await ref.read(gameRepositoryProvider).appendNightLog(gameId: gameId, entries: lines);
    }

    final cursor = _cursorAfter(action, s.cursor);
    await _persist(result.state, cursor);

    final deaths = action is FinalizeNight
        ? [
            for (final e in result.events)
              if (e is PlayerDied) ResolvedDeath(e.playerId, e.cause),
          ]
        : s.lastResolution;
    _emit(s, engine: result.state, cursor: cursor, lastResolution: deaths);
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
    await _persist(s.engine, cursor);
    _emit(s, cursor: cursor);
  }

  SessionCursor _cursorAfter(GameAction action, SessionCursor c) {
    switch (action) {
      // The Witch's turn spans several taps (life and/or death, then done);
      // FinalizeNight flips the phase to day, which the UI keys off instead.
      case FinalizeNight():
      case WitchLifePotion():
      case WitchDeathPotion():
        return c;
      default:
        return SessionCursor(stepIndex: c.stepIndex + 1, subStep: NightSubStep.identify);
    }
  }

  void _emit(
    GameSessionState prev, {
    GameState? engine,
    SessionCursor? cursor,
    List<ResolvedDeath>? lastResolution,
  }) {
    final nextEngine = engine ?? prev.engine;
    state = AsyncData(
      GameSessionState(
        engine: nextEngine,
        cursor: cursor ?? prev.cursor,
        tonight: buildNightScript(engine: nextEngine, composition: prev.composition),
        composition: prev.composition,
        lastResolution: lastResolution ?? prev.lastResolution,
      ),
    );
  }
}
