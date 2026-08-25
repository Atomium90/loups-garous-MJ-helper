import '../role_registry/role_registry.dart';
import 'death_cascade.dart';
import 'death_cause.dart';
import 'game_action.dart';
import 'game_event.dart';
import 'game_state.dart';
import 'pending_decision.dart';
import 'player.dart';

class ActionResult {
  final GameState state;
  final List<GameEvent> events;

  const ActionResult({required this.state, required this.events});
}

/// Thrown when a GameAction is not valid for the current state (wrong
/// phase/night, dead target, reused potion, etc).
class InvalidActionError implements Exception {
  final String message;
  InvalidActionError(this.message);

  @override
  String toString() => 'InvalidActionError: $message';
}

/// A pure, synchronous state transition function: it never decides
/// anything on its own, it only reacts to a GameAction the MJ reports.
class GameStateMachine {
  const GameStateMachine();

  ActionResult apply({
    required GameState state,
    required GameAction action,
    required RoleRegistry roleRegistry,
  }) {
    switch (action) {
      case VoleurSwap():
        return _applyVoleurSwap(state, action, roleRegistry);
      case CupidonPair():
        return _applyCupidonPair(state, action);
      case WolvesTarget():
        return _applyWolvesTarget(state, action);
      case WitchLifePotion():
        return _applyWitchLifePotion(state);
      case WitchDeathPotion():
        return _applyWitchDeathPotion(state, action);
      case ElectCaptain():
        return _applyElectCaptain(state, action);
      case StartNextNight():
        return _applyStartNextNight(state);
      case FinalizeNight():
        return _applyFinalizeNight(state, roleRegistry);
      case DayVoteElimination():
        return _applyDayVoteElimination(state, action, roleRegistry);
    }
  }

  ActionResult _applyVoleurSwap(
    GameState state,
    VoleurSwap action,
    RoleRegistry roleRegistry,
  ) {
    _requireNight(state, 1, 'Voleur can only act on night 1');
    final voleur = state.playerById(action.voleurPlayerId);
    _requireAlive(voleur, 'Voleur');

    final stolenRoleId = action.stolenRoleId;
    if (stolenRoleId != null) {
      roleRegistry.byId(stolenRoleId); // throws RoleNotFoundException if unknown
    }
    final resolvedRoleId = stolenRoleId ?? voleur.roleId;

    final updatedPlayers = [
      for (final p in state.players)
        if (p.id == voleur.id) p.copyWith(roleId: resolvedRoleId) else p,
    ];
    return ActionResult(
      state: state.copyWith(players: updatedPlayers),
      events: [VoleurSwapped(voleurPlayerId: voleur.id, newRoleId: resolvedRoleId)],
    );
  }

  ActionResult _applyCupidonPair(GameState state, CupidonPair action) {
    _requireNight(state, 1, 'Cupidon can only act on night 1');
    if (state.lovers != null) {
      throw InvalidActionError('Cupidon has already paired two players this game');
    }
    if (action.playerAId == action.playerBId) {
      throw InvalidActionError('Cupidon cannot pair a player with themselves');
    }
    _requireAlive(state.playerById(action.playerAId), 'playerA');
    _requireAlive(state.playerById(action.playerBId), 'playerB');

    return ActionResult(
      state: state.copyWith(lovers: LoversPair(action.playerAId, action.playerBId)),
      events: [LoversPaired(playerAId: action.playerAId, playerBId: action.playerBId)],
    );
  }

  ActionResult _applyWolvesTarget(GameState state, WolvesTarget action) {
    _requireAlive(state.playerById(action.targetPlayerId), 'wolves target');
    return ActionResult(
      state: state.copyWith(pendingWolfVictimId: action.targetPlayerId),
      events: const [],
    );
  }

  ActionResult _applyWitchLifePotion(GameState state) {
    if (state.witch.lifePotionUsed) {
      throw InvalidActionError('Witch has already used her life potion');
    }
    if (state.pendingWolfVictimId == null) {
      throw InvalidActionError('No wolf victim to save');
    }
    return ActionResult(
      state: state.copyWith(
        pendingWolfVictimId: null,
        witch: state.witch.copyWith(lifePotionUsed: true),
      ),
      events: const [WitchLifePotionUsed()],
    );
  }

  ActionResult _applyWitchDeathPotion(GameState state, WitchDeathPotion action) {
    if (state.witch.deathPotionUsed) {
      throw InvalidActionError('Witch has already used her death potion');
    }
    _requireAlive(state.playerById(action.targetPlayerId), 'witch death potion target');

    return ActionResult(
      state: state.copyWith(
        pendingWitchDeathTargetId: action.targetPlayerId,
        witch: state.witch.copyWith(deathPotionUsed: true),
      ),
      events: [WitchDeathPotionUsed(targetPlayerId: action.targetPlayerId)],
    );
  }

  ActionResult _applyElectCaptain(GameState state, ElectCaptain action) {
    if (state.phase != GamePhase.day) {
      throw InvalidActionError('Captain can only be elected during the day');
    }
    if (state.captainPlayerId != null) {
      throw InvalidActionError('A captain has already been elected');
    }
    _requireAlive(state.playerById(action.playerId), 'captain candidate');

    return ActionResult(
      state: state.copyWith(captainPlayerId: action.playerId),
      events: [CaptainElected(playerId: action.playerId)],
    );
  }

  ActionResult _applyFinalizeNight(GameState state, RoleRegistry roleRegistry) {
    if (state.phase != GamePhase.night) {
      throw InvalidActionError('Can only finalize the night during the night phase');
    }
    if (state.cascade != null) {
      throw InvalidActionError('A death cascade is still pending a decision');
    }

    var currentState = state;
    final events = <GameEvent>[];
    final queue = <CascadeTask>[];

    final pendingKills = <(String, DeathCause)>[
      if (state.pendingWolfVictimId != null) (state.pendingWolfVictimId!, const WolvesKill()),
      if (state.pendingWitchDeathTargetId != null)
        (state.pendingWitchDeathTargetId!, const WitchDeathPotionKill()),
    ];
    for (final (playerId, cause) in pendingKills) {
      if (!currentState.playerById(playerId).alive) {
        continue; // dedupes an identical wolf/witch target: already killed above
      }
      currentState = currentState.killPlayer(playerId);
      events.add(PlayerDied(playerId: playerId, cause: cause));
      queue.addAll(deathCascadeTasks(playerId));
    }

    final drained = drainCascade(state: currentState, queue: queue, roleRegistry: roleRegistry);
    events
      ..addAll(drained.events)
      ..add(NightFinalized(nightIndex: state.nightIndex));

    return ActionResult(
      state: drained.state.copyWith(
        phase: GamePhase.day,
        pendingWolfVictimId: null,
        pendingWitchDeathTargetId: null,
        cascade: drained.pendingDecision == null
            ? null
            : CascadeState(decision: drained.pendingDecision!, remainingQueue: drained.remainingQueue),
      ),
      events: events,
    );
  }

  ActionResult _applyDayVoteElimination(
    GameState state,
    DayVoteElimination action,
    RoleRegistry roleRegistry,
  ) {
    if (state.phase != GamePhase.day) {
      throw InvalidActionError('Day vote elimination can only happen during the day');
    }
    if (state.cascade != null) {
      throw InvalidActionError('A death cascade is still pending a decision');
    }
    _requireAlive(state.playerById(action.targetPlayerId), 'day vote target');

    final killed = state.killPlayer(action.targetPlayerId);
    final events = <GameEvent>[
      PlayerDied(playerId: action.targetPlayerId, cause: const DayVoteKill()),
    ];
    final drained = drainCascade(
      state: killed,
      queue: deathCascadeTasks(action.targetPlayerId),
      roleRegistry: roleRegistry,
    );
    events.addAll(drained.events);

    return ActionResult(
      state: drained.state.copyWith(
        cascade: drained.pendingDecision == null
            ? null
            : CascadeState(decision: drained.pendingDecision!, remainingQueue: drained.remainingQueue),
      ),
      events: events,
    );
  }

  ActionResult _applyStartNextNight(GameState state) {
    if (state.phase != GamePhase.day) {
      throw InvalidActionError('Can only start the next night from the day phase');
    }
    if (state.cascade != null) {
      throw InvalidActionError('A death cascade is still pending a decision');
    }
    return ActionResult(
      state: state.copyWith(nightIndex: state.nightIndex + 1, phase: GamePhase.night),
      events: const [],
    );
  }

  void _requireAlive(Player player, String label) {
    if (!player.alive) {
      throw InvalidActionError('$label (${player.id}) is not alive');
    }
  }

  void _requireNight(GameState state, int nightIndex, String message) {
    if (state.nightIndex != nightIndex) {
      throw InvalidActionError(message);
    }
  }
}
