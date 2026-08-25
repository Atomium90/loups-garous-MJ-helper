import '../role_registry/role_registry.dart';
import 'game_action.dart';
import 'game_event.dart';
import 'game_state.dart';
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

  ActionResult _applyStartNextNight(GameState state) {
    if (state.phase != GamePhase.day) {
      throw InvalidActionError('Can only start the next night from the day phase');
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
