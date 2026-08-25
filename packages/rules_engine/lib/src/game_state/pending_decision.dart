/// A death cascade paused on a choice only the MJ can make. Resolved by a
/// follow-up GameAction (HunterShoot, CaptainNameSuccessor).
sealed class PendingDecision {}

class PendingHunterShot implements PendingDecision {
  final String deadHunterId;
  const PendingHunterShot({required this.deadHunterId});
}

class PendingCaptainSuccession implements PendingDecision {
  final String deadCaptainId;
  const PendingCaptainSuccession({required this.deadCaptainId});
}

/// One unit of cascade work for a single player. Every death enqueues
/// exactly the three of these, in order, together (see
/// death_cascade.dart's deathCascadeTasks), only at the moment that
/// player transitions alive -> dead.
sealed class CascadeTask {
  final String playerId;
  const CascadeTask(this.playerId);
}

/// Checks the dying player's own role for an onDeath effect (currently:
/// Chasseur's shot).
class ResolveOnDeathEffect extends CascadeTask {
  const ResolveOnDeathEffect(super.playerId);
}

/// Checks whether the dying player currently holds the elected captain
/// status, independently of their role.
class ResolveCaptainStatus extends CascadeTask {
  const ResolveCaptainStatus(super.playerId);
}

/// Checks whether the dying player has a living lover.
class ResolveLoversCascade extends CascadeTask {
  const ResolveLoversCascade(super.playerId);
}

class CascadeState {
  final PendingDecision decision;
  final List<CascadeTask> remainingQueue;

  const CascadeState({required this.decision, required this.remainingQueue});
}
