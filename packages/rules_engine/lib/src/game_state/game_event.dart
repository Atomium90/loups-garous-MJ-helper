import 'death_cause.dart';

/// Something that happened as a result of a GameAction, for a future
/// journal/UI layer to display.
sealed class GameEvent {}

class PlayerDied implements GameEvent {
  final String playerId;
  final DeathCause cause;

  const PlayerDied({required this.playerId, required this.cause});
}

class NightFinalized implements GameEvent {
  final int nightIndex;

  const NightFinalized({required this.nightIndex});
}

class HunterShotSkipped implements GameEvent {
  final String hunterPlayerId;

  const HunterShotSkipped({required this.hunterPlayerId});
}

class CaptainSuccessionSkipped implements GameEvent {
  final String deadCaptainId;

  const CaptainSuccessionSkipped({required this.deadCaptainId});
}

class HunterShotFired implements GameEvent {
  final String hunterPlayerId;
  final String targetPlayerId;

  const HunterShotFired({required this.hunterPlayerId, required this.targetPlayerId});
}

class CaptainSuccession implements GameEvent {
  final String fromPlayerId;
  final String toPlayerId;

  const CaptainSuccession({required this.fromPlayerId, required this.toPlayerId});
}

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
