import 'package:rules_engine/rules_engine.dart';

import '../../data/models/night_log_entry.dart';

/// The journal lines a single MJ action produces, in the Journal's copy
/// style. Each line is written at the moment its own action is reported, so a
/// force-quit between two steps never loses or garbles one. Deaths get no line
/// of their own - the action lines imply them and the recaps summarise them
/// (the one exception, a lover's grief death, is journalled by the caller from
/// the resulting events).
List<NightLogEntry> nightLogEntriesFor(GameAction action, GameState before) {
  final label = before.phase == GamePhase.night
      ? 'NUIT ${before.nightIndex}'
      : 'JOUR ${before.nightIndex}';

  NightLogEntry entry(String iconName, String line) =>
      NightLogEntry(phaseLabel: label, iconName: iconName, line: line);

  String name(String id) => before.playerById(id).name;

  switch (action) {
    case WolvesTarget(:final targetPlayerId):
      return [entry('wolves', 'Les Loups désignent ${name(targetPlayerId)}')];

    case WitchLifePotion():
      final victimId = before.pendingWolfVictimId;
      if (victimId == null) return const [];
      return [entry('flask', 'La Sorcière sauve ${name(victimId)}')];

    case WitchDeathPotion(:final targetPlayerId):
      return [entry('flask', 'La Sorcière empoisonne ${name(targetPlayerId)}')];

    case CupidonPair(:final playerAId, :final playerBId):
      return [entry('cupid', 'Cupidon unit ${name(playerAId)} et ${name(playerBId)}')];

    case VoleurSwap(:final stolenRoleId):
      return [
        stolenRoleId == null
            ? entry('thief', 'Le Voleur garde sa carte')
            : entry(
                'thief',
                'Le Voleur échange sa carte contre ${RoleRegistry.base.byId(stolenRoleId).name}',
              ),
      ];

    case ElectCaptain(:final playerId):
      return [entry('crown', '${name(playerId)} est Capitaine')];

    case CaptainNameSuccessor(:final successorPlayerId):
      return [entry('crown', '${name(successorPlayerId)} devient Capitaine')];

    case DayVoteElimination(:final targetPlayerId):
      return [entry('vote', 'Le village élimine ${name(targetPlayerId)}')];

    case HunterShoot(:final targetPlayerId):
      return [
        targetPlayerId == null
            ? entry('hunter', 'Le Chasseur ne tire pas')
            : entry('hunter', 'Le Chasseur emporte ${name(targetPlayerId)}'),
      ];

    default:
      return const [];
  }
}
