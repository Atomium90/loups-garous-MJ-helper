/// A fact the MJ reports to the state machine. GameStateMachine never
/// invents an action itself, it only reacts to these.
sealed class GameAction {}

class VoleurSwap implements GameAction {
  final String voleurPlayerId;

  /// Null means he keeps his own card.
  final String? stolenRoleId;

  const VoleurSwap({required this.voleurPlayerId, this.stolenRoleId});
}

class CupidonPair implements GameAction {
  final String playerAId;
  final String playerBId;

  const CupidonPair({required this.playerAId, required this.playerBId});
}

class WolvesTarget implements GameAction {
  final String targetPlayerId;

  const WolvesTarget({required this.targetPlayerId});
}

class WitchLifePotion implements GameAction {
  const WitchLifePotion();
}

class WitchDeathPotion implements GameAction {
  final String targetPlayerId;

  const WitchDeathPotion({required this.targetPlayerId});
}

class ElectCaptain implements GameAction {
  final String playerId;

  const ElectCaptain({required this.playerId});
}

class StartNextNight implements GameAction {
  const StartNextNight();
}
