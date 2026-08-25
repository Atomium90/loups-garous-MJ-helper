/// Something that happened as a result of a GameAction, for a future
/// journal/UI layer to display.
sealed class GameEvent {}

class VoleurSwapped implements GameEvent {
  final String voleurPlayerId;
  final String newRoleId;

  const VoleurSwapped({required this.voleurPlayerId, required this.newRoleId});
}

class LoversPaired implements GameEvent {
  final String playerAId;
  final String playerBId;

  const LoversPaired({required this.playerAId, required this.playerBId});
}

class WitchLifePotionUsed implements GameEvent {
  const WitchLifePotionUsed();
}

class WitchDeathPotionUsed implements GameEvent {
  final String targetPlayerId;

  const WitchDeathPotionUsed({required this.targetPlayerId});
}

class CaptainElected implements GameEvent {
  final String playerId;

  const CaptainElected({required this.playerId});
}
