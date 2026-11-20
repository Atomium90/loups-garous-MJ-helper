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

extension PlayerPack on Player {
  /// Whether the player wakes with the wolves: the wolf side, and the White Werewolf who plays
  /// for himself but feasts with them.
  bool wakesWithWolvesIn(RoleRegistry registry) =>
      sideIn(registry) == Team.werewolves || roleId == 'loup_garou_blanc';
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

  /// The three players the Fox looks at when he picks [middlePlayerId]: the living neighbours on
  /// either side, and the middle player. Fewer than three when the table is nearly empty.
  List<Player> foxTrio(String middlePlayerId) {
    final around = aliveNeighbours(middlePlayerId);
    final trio = <Player>[];
    for (final p in [around.left, playerById(middlePlayerId), around.right]) {
      if (p != null && p.alive && !trio.any((q) => q.id == p.id)) trio.add(p);
    }
    return trio;
  }

  /// Whether at least one of [group] plays with the wolves, as far as the app knows: a player
  /// whose card was never noted counts for the village.
  bool wolfAmong(Iterable<Player> group, RoleRegistry registry) =>
      group.any((p) => p.sideIn(registry) == Team.werewolves);

  /// Whether the Bear Tamer [bearPlayerId] growls this morning: a living neighbour plays with
  /// the wolves, or he does himself (infected, he growls every day). A dead Bear Tamer is silent.
  bool bearGrowls(String bearPlayerId, RoleRegistry registry) {
    final bear = playerById(bearPlayerId);
    if (!bear.alive) return false;
    if (bear.sideIn(registry) == Team.werewolves) return true;
    final around = aliveNeighbours(bearPlayerId);
    return wolfAmong([?around.left, ?around.right], registry);
  }

  /// Whether [player] wakes with the wolves: the wolf side, and the White Werewolf who plays
  /// for himself but feasts with them. The wolves never choose one of these as their victim.
  bool wakesWithWolves(Player player, RoleRegistry registry) =>
      player.wakesWithWolvesIn(registry);

  /// Whether a wolf, the Wild Child or the Wolf-Hound has been eliminated: the Big Bad Wolf's
  /// second victim stops from then on.
  bool wolfSideLost(RoleRegistry registry) => players.any(
    (p) =>
        !p.alive &&
        (wakesWithWolves(p, registry) ||
            p.roleId == 'enfant_sauvage' ||
            p.roleId == 'chien_loup'),
  );

  /// The first living wolf to the left of [playerId], going round the table the other way from the
  /// roster order, as far as the cards the app knows tell. Null when none is known. "Left" is the
  /// player's own left.
  Player? firstWolfToLeftOf(String playerId, RoleRegistry registry) {
    final seat = players.indexWhere((p) => p.id == playerId);
    if (seat < 0) throw PlayerNotFoundException(playerId);
    for (var i = 1; i < players.length; i++) {
      final candidate = players[(seat - i) % players.length];
      if (candidate.alive && candidate.wakesWithWolvesIn(registry)) return candidate;
    }
    return null;
  }
}
