import 'package:rules_engine/rules_engine.dart';

import '../../data/models/night_log_entry.dart';

/// The journal lines a single MJ action produces, in the JR screen's copy
/// style. Each line is written at the moment its own action is reported (not
/// deferred to FinalizeNight), so a force-quit between two steps never loses
/// or garbles one. Deaths get no line of their own - the action lines imply
/// them and the day recap summarises them.
List<NightLogEntry> nightLogEntriesFor(GameAction action, GameState before) {
  final label = 'NUIT ${before.nightIndex}';

  NightLogEntry entry(String iconName, String line) =>
      NightLogEntry(phaseLabel: label, iconName: iconName, line: line);

  switch (action) {
    case WolvesTarget(:final targetPlayerId):
      return [entry('wolves', 'Les Loups désignent ${before.playerById(targetPlayerId).name}')];

    case WitchLifePotion():
      final victimId = before.pendingWolfVictimId;
      if (victimId == null) return const [];
      return [entry('flask', 'La Sorcière sauve ${before.playerById(victimId).name}')];

    case WitchDeathPotion(:final targetPlayerId):
      return [entry('flask', 'La Sorcière empoisonne ${before.playerById(targetPlayerId).name}')];

    case CupidonPair(:final playerAId, :final playerBId):
      return [
        entry(
          'cupid',
          'Cupidon unit ${before.playerById(playerAId).name} et ${before.playerById(playerBId).name}',
        ),
      ];

    default:
      return const [];
  }
}
