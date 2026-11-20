import '../models/team.dart';
import '../role_registry/role_registry.dart';
import 'game_state.dart';
import 'player.dart';

/// Who plays for whom right now. The one place that answers it, so a screen never compares a
/// role's team on its own: a player's side is their [Player.teamOverride] when they have one
/// (an infected villager is a wolf), their role's team otherwise. A role the registry does not
/// know, or the placeholder of a player whose card is unknown, counts for the village.
extension PlayerSide on Player {
  Team sideIn(RoleRegistry registry) =>
      teamOverride ?? registry.byIdOrNull(roleId)?.team ?? Team.village;
}

extension GameStateSides on GameState {
  /// Living players on [side].
  int aliveOnSide(Team side, RoleRegistry registry) =>
      alivePlayers.where((p) => p.sideIn(registry) == side).length;

  /// Living players who play with the wolves.
  int aliveWolves(RoleRegistry registry) => aliveOnSide(Team.werewolves, registry);

  /// The living players on each side of [playerId] around the table. The roster order is the
  /// order of the seats, so neighbours are the next living players either way round, dead seats
  /// skipped. With a single other player alive both sides are that player; with none, both are
  /// null.
  ({Player? left, Player? right}) aliveNeighbours(String playerId) {
    final seat = players.indexWhere((p) => p.id == playerId);
    if (seat < 0) throw PlayerNotFoundException(playerId);
    Player? next(int step) {
      for (var i = 1; i < players.length; i++) {
        final candidate = players[(seat + step * i) % players.length];
        if (candidate.alive) return candidate;
      }
      return null;
    }

    return (left: next(-1), right: next(1));
  }
}
