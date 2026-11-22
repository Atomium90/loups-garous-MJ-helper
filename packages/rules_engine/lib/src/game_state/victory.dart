import 'package:collection/collection.dart';

import '../models/team.dart';
import '../role_registry/role_registry.dart';
import 'game_state.dart';
import 'player.dart';
import 'sides.dart';

/// Who the table looks to have won.
enum VictoryKind {
  /// Only villagers are left.
  village,

  /// Only the wolf side is left.
  werewolves,

  /// The White Werewolf is the only one left.
  whiteWolf,

  /// The Angel was eliminated at the first vote or during the first night.
  angel,

  /// Every living player but the Piper has been charmed.
  piper,

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

  // The Angel wins the moment he is eliminated at the first vote (before night 1) or during
  // night 1 - unless he is one of the lovers, who give up their own goal.
  final angelOut = state.players.any(
    (p) =>
        p.roleId == 'ange' &&
        !p.alive &&
        state.lovers?.partnerOf(p.id) == null &&
        (p.diedOnNight == 0 || (p.diedOnNight == 1 && p.diedOnPhase == GamePhase.night)),
  );
  if (angelOut) return VictoryKind.angel;

  // Before the first night nobody's card is known yet (a player whose card is unknown counts for
  // the village): no side can be said to have won, only the Angel's early win above.
  if (state.nightIndex == 0) return null;

  if (alive.isEmpty) return VictoryKind.nobody;

  final lovers = state.lovers;
  if (lovers != null && alive.length == 2) {
    final ids = alive.map((p) => p.id).toSet();
    if (ids.containsAll([lovers.playerAId, lovers.playerBId])) {
      final sides = alive.map((p) => state.sideOf(p, registry)).toSet();
      final wolfAndOther = sides.contains(Team.werewolves) && sides.length > 1;
      final withSolo = sides.contains(Team.solo);
      if (wolfAndOther || withSolo) return VictoryKind.lovers;
    }
  }

  if (alive.length == 1 && alive.single.roleId == 'loup_garou_blanc') {
    return VictoryKind.whiteWolf;
  }

  // The Piper (while he has not been infected into a wolf) wins the instant everyone else alive
  // is charmed, wolves included.
  final piper = alive
      .where((p) => p.roleId == 'joueur_de_flute' && p.teamOverride != Team.werewolves)
      .firstOrNull;
  if (piper != null &&
      alive.every((p) => p.id == piper.id || p.hasStatus(PlayerStatus.charmed))) {
    return VictoryKind.piper;
  }

  final sides = alive.map((p) => state.sideOf(p, registry)).toSet();
  if (sides.contains(Team.solo)) return null;
  if (sides.length == 1 && sides.single == Team.werewolves) return VictoryKind.werewolves;
  if (!sides.contains(Team.werewolves)) return VictoryKind.village;
  return null;
}
