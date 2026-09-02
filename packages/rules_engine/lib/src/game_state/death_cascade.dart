import '../models/death_effect.dart';
import '../role_registry/role_registry.dart';
import 'death_cause.dart';
import 'game_event.dart';
import 'game_state.dart';
import 'pending_decision.dart';

/// The three ordered tasks a single death always enqueues, together, only
/// at the moment that player transitions alive -> dead.
List<CascadeTask> deathCascadeTasks(String playerId) => [
  ResolveOnDeathEffect(playerId),
  ResolveCaptainStatus(playerId),
  ResolveLoversCascade(playerId),
];

class CascadeResult {
  final GameState state;
  final List<GameEvent> events;

  /// Non-null iff the cascade paused mid-way on a choice only the MJ can
  /// make. [remainingQueue] is what's left to process once it's resolved.
  final PendingDecision? pendingDecision;
  final List<CascadeTask> remainingQueue;

  const CascadeResult({
    required this.state,
    required this.events,
    this.pendingDecision,
    this.remainingQueue = const [],
  });
}

/// Drains [queue] breadth-first. A task for an already-dead player is a
/// no-op: a player transitions alive -> dead exactly once, and that single
/// transition is the only place that ever enqueues their tasks, so this is
/// what prevents infinite loops or double-processing (e.g. two lovers,
/// each cascading into the other: by the time the second one's task runs,
/// the first one is already dead).
CascadeResult drainCascade({
  required GameState state,
  required List<CascadeTask> queue,
  required RoleRegistry roleRegistry,
}) {
  var currentState = state;
  final events = <GameEvent>[];
  final q = List<CascadeTask>.from(queue);

  while (q.isNotEmpty) {
    final task = q.removeAt(0);
    // The task's own subject is always already dead: killPlayer always runs
    // before deathCascadeTasks enqueues their tasks, never after. The
    // aliveness checks that matter (a lover's partner, a captain's
    // identity) happen inside each case below, on a *different* player.
    final player = currentState.playerById(task.playerId);

    switch (task) {
      case ResolveOnDeathEffect():
        final role = roleRegistry.byId(player.roleId);
        final candidates = currentState.alivePlayers.where((p) => p.id != player.id);
        switch (role.onDeath) {
          case DeathEffect.none:
            break;
          case DeathEffect.hunterShot:
            if (candidates.isEmpty) {
              events.add(HunterShotSkipped(hunterPlayerId: player.id));
            } else {
              return CascadeResult(
                state: currentState,
                events: events,
                pendingDecision: PendingHunterShot(deadHunterId: player.id),
                remainingQueue: q,
              );
            }
        }

      case ResolveCaptainStatus():
        if (currentState.captainPlayerId == player.id) {
          final candidates = currentState.alivePlayers.where((p) => p.id != player.id);
          if (candidates.isEmpty) {
            currentState = currentState.copyWith(captainPlayerId: null);
            events.add(CaptainSuccessionSkipped(deadCaptainId: player.id));
          } else {
            return CascadeResult(
              state: currentState,
              events: events,
              pendingDecision: PendingCaptainSuccession(deadCaptainId: player.id),
              remainingQueue: q,
            );
          }
        }

      case ResolveLoversCascade():
        final partnerId = currentState.lovers?.partnerOf(player.id);
        if (partnerId != null && currentState.playerById(partnerId).alive) {
          final cause = LoversCascadeKill(causingPlayerId: player.id);
          currentState = currentState.killPlayer(partnerId, cause: cause);
          events.add(PlayerDied(playerId: partnerId, cause: cause));
          q.addAll(deathCascadeTasks(partnerId));
        }
    }
  }

  return CascadeResult(state: currentState, events: events);
}
