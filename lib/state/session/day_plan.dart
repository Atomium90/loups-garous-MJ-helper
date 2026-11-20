import 'package:rules_engine/rules_engine.dart';

import 'session_cursor.dart';

/// The stages of today, in the order the MJ goes through them, given what the game looks like
/// now. [DayStage]'s declaration order is the order of the day: a role that adds a stage (the
/// bear growling at the start of the day, a second vote) adds a value in its place and a line
/// here, and every screen that moves on goes through [nextDayStage].
List<DayStage> dayStagesFor(GameState engine) => [
  DayStage.recap,
  // After the victims are named, a living Bear Tamer growls if a neighbour is a wolf.
  if (engine.players.any((p) => p.alive && p.roleId == 'montreur_d_ours')) DayStage.growl,
  // The first morning, the village elects its Capitaine if it has none yet.
  if (engine.nightIndex == 1 && engine.captainPlayerId == null) DayStage.captain,
  DayStage.vote,
  DayStage.done,
];

/// The stage that follows [after], computed on the game as it is now: the stage just done may
/// no longer be one of today's (the Capitaine was just elected), so this is the first of today's
/// stages that comes later in the day, not "the entry after [after] in the list".
DayStage nextDayStage(DayStage after, GameState engine) {
  final stages = dayStagesFor(engine);
  return stages.firstWhere((s) => s.index > after.index, orElse: () => stages.last);
}
