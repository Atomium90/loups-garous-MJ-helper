import '../models/team.dart';
import '../role_registry/role_registry.dart';
import 'game_state.dart';
import 'sides.dart';

/// Who the table looks to have won.
enum VictoryKind {
  /// Only villagers are left.
  village,

  /// Only the wolf side is left.
  werewolves,

  /// The two lovers, from opposite sides, are the last ones standing.
  lovers,

  /// Nobody is left alive.
  nobody,
}

/// What the state looks like it says about the end of the game. A proposal, never a decision:
/// the MJ ends the game, and the app only offers the winner it would pick. Returns null while
/// the game plainly goes on - including whenever a solo role is still alive, whose victory is
/// that role's own business.
VictoryKind? proposeVictory(GameState state, RoleRegistry registry) {
  final alive = state.alivePlayers;
  if (alive.isEmpty) return VictoryKind.nobody;

  final lovers = state.lovers;
  if (lovers != null && alive.length == 2) {
    final ids = alive.map((p) => p.id).toSet();
    if (ids.containsAll([lovers.playerAId, lovers.playerBId])) {
      final sides = alive.map((p) => p.sideIn(registry)).toSet();
      final wolfAndOther = sides.contains(Team.werewolves) && sides.length > 1;
      final withSolo = sides.contains(Team.solo);
      if (wolfAndOther || withSolo) return VictoryKind.lovers;
    }
  }

  final sides = alive.map((p) => p.sideIn(registry)).toSet();
  if (sides.contains(Team.solo)) return null;
  if (sides.length == 1 && sides.single == Team.werewolves) return VictoryKind.werewolves;
  if (!sides.contains(Team.werewolves)) return VictoryKind.village;
  return null;
}
