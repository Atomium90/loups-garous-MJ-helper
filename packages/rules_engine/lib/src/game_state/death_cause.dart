/// Why a player died, for a future journal/UI layer to explain.
sealed class DeathCause {}

class WolvesKill implements DeathCause {
  const WolvesKill();
}

class WitchDeathPotionKill implements DeathCause {
  const WitchDeathPotionKill();
}

class DayVoteKill implements DeathCause {
  const DayVoteKill();
}

class HunterShotKill implements DeathCause {
  final String shooterPlayerId;
  const HunterShotKill({required this.shooterPlayerId});
}

class LoversCascadeKill implements DeathCause {
  final String causingPlayerId;
  const LoversCascadeKill({required this.causingPlayerId});
}
