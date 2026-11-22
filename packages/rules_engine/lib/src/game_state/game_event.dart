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

class RoleRevealed implements GameEvent {
  final String playerId;
  final String roleId;

  const RoleRevealed({required this.playerId, required this.roleId});
}

class FoxSniffed implements GameEvent {
  final String middlePlayerId;
  final bool wolfFound;

  const FoxSniffed({required this.middlePlayerId, required this.wolfFound});
}

class WildChildModelChosen implements GameEvent {
  final String childPlayerId;
  final String modelPlayerId;

  const WildChildModelChosen({required this.childPlayerId, required this.modelPlayerId});
}

class ChienLoupChose implements GameEvent {
  final String playerId;
  final bool wolf;

  const ChienLoupChose({required this.playerId, required this.wolf});
}

class VictimInfected implements GameEvent {
  final String playerId;

  const VictimInfected({required this.playerId});
}

/// The Elder survived a first bite: the table is not told.
class ElderSurvived implements GameEvent {
  final String playerId;

  const ElderSurvived({required this.playerId});
}

/// The villagers lost their special powers because the Elder was eliminated.
class VillagersLostPowers implements GameEvent {
  final String elderPlayerId;

  const VillagersLostPowers({required this.elderPlayerId});
}

class KnightContaminated implements GameEvent {
  final String wolfPlayerId;

  const KnightContaminated({required this.wolfPlayerId});
}

class PlayersCharmed implements GameEvent {
  final List<String> playerIds;

  const PlayersCharmed({required this.playerIds});
}

/// The wolves picked a player the Defender protected: nobody died of it.
class DefenderSaved implements GameEvent {
  final String playerId;

  const DefenderSaved({required this.playerId});
}

/// The village voted against the Village Idiot: he shows his card and is pardoned.
class IdiotPardoned implements GameEvent {
  final String playerId;

  const IdiotPardoned({required this.playerId});
}

/// The vote was tied and the Scapegoat took the blame.
class ScapegoatBlamed implements GameEvent {
  final String playerId;

  const ScapegoatBlamed({required this.playerId});
}

/// The dead Scapegoat named who votes on the next day.
class VotersChosen implements GameEvent {
  final Set<String> allowedPlayerIds;

  const VotersChosen({required this.allowedPlayerIds});
}

/// The Wandering Judge called for a second vote.
class JudgeSignGiven implements GameEvent {
  const JudgeSignGiven();
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
