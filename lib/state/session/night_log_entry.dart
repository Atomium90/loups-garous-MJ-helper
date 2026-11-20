import 'package:rules_engine/rules_engine.dart';

import '../../data/models/night_log_entry.dart';

/// The journal lines a single MJ action produces, as data: what happened and to
/// whom, with no words. The Journal turns each into a sentence in the app's language.
/// Each line is written at the moment its own action is reported, so a
/// force-quit between two steps never loses or garbles one. Deaths get no line
/// of their own - the action lines imply them and the recaps summarise them
/// (the one exception, a lover's grief death, is journalled by the caller from
/// the resulting events).
List<NightLogEntry> nightLogEntriesFor(GameAction action, GameState before) {
  final phase = before.phase == GamePhase.night ? JournalPhase.night : JournalPhase.day;

  NightLogEntry entry(JournalKind kind, [Map<String, String> args = const {}]) =>
      NightLogEntry(phase: phase, phaseIndex: before.nightIndex, kind: kind, args: args);

  String name(String id) => before.playerById(id).name;

  switch (action) {
    case WolvesTarget(:final targetPlayerId):
      return [entry(JournalKind.wolvesTarget, {'player': name(targetPlayerId)})];

    case WitchLifePotion():
      final victimId = before.pendingWolfVictimId;
      if (victimId == null) return const [];
      return [entry(JournalKind.witchSave, {'player': name(victimId)})];

    case WitchDeathPotion(:final targetPlayerId):
      return [entry(JournalKind.witchPoison, {'player': name(targetPlayerId)})];

    case CupidonPair(:final playerAId, :final playerBId):
      return [
        entry(JournalKind.cupidPair, {'player': name(playerAId), 'other': name(playerBId)}),
      ];

    case FoxSniff(:final middlePlayerId, :final wolfFound):
      return [
        entry(
          wolfFound ? JournalKind.foxFindsWolf : JournalKind.foxFindsNone,
          {'player': name(middlePlayerId)},
        ),
      ];

    case WildChildChooseModel(:final childPlayerId, :final modelPlayerId):
      return [
        entry(JournalKind.wildChildModel, {
          'player': name(childPlayerId),
          'other': name(modelPlayerId),
        }),
      ];

    case ChienLoupChoose(:final playerId, :final wolf):
      return [
        entry(
          wolf ? JournalKind.chienLoupWolf : JournalKind.chienLoupVillage,
          {'player': name(playerId)},
        ),
      ];

    case InfectVictim():
      final victimId = before.pendingWolfVictimId;
      if (victimId == null) return const [];
      return [entry(JournalKind.infection, {'player': name(victimId)})];

    case BigBadWolfTarget(:final targetPlayerId):
      return [entry(JournalKind.bigBadWolfTarget, {'player': name(targetPlayerId)})];

    case WhiteWolfEat(:final targetPlayerId):
      return [entry(JournalKind.whiteWolfEats, {'player': name(targetPlayerId)})];

    case VoleurSwap(:final stolenRoleId):
      return [
        stolenRoleId == null
            ? entry(JournalKind.thiefKeep)
            : entry(JournalKind.thiefSwap, {'role': stolenRoleId}),
      ];

    case ElectCaptain(:final playerId):
      return [entry(JournalKind.captainElected, {'player': name(playerId)})];

    case CaptainNameSuccessor(:final successorPlayerId):
      return [entry(JournalKind.captainSuccessor, {'player': name(successorPlayerId)})];

    case DayVoteElimination(:final targetPlayerId):
      return [entry(JournalKind.villageEliminates, {'player': name(targetPlayerId)})];

    case HunterShoot(:final targetPlayerId):
      return [
        targetPlayerId == null
            ? entry(JournalKind.hunterNoShot)
            : entry(JournalKind.hunterShoots, {'player': name(targetPlayerId)}),
      ];

    default:
      return const [];
  }
}
