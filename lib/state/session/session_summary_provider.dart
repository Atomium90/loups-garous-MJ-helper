import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../data/database/app_database.dart';
import '../../data/models/night_log_entry.dart';
import '../providers/game_repository_provider.dart';
import 'night_script.dart';
import 'session_cursor.dart';

/// Where a game in progress stands, away from any language: the UI words it ("Nuit 1 ·
/// Voyante", "Day 1 · recap") on Home's "en cours" card. Null before the night starts (the
/// card then shows a flat fallback).
enum SummaryStep {
  /// A night role's turn; [SessionSummary.roleId] says which.
  role,
  nightEnd,
  recap,
  bearGrowl,
  captainElection,
  villageVote,
  dayDone,
  chainEffect,
}

class SessionSummary {
  final JournalPhase phase;
  final int nightIndex;
  final SummaryStep step;

  /// The role whose turn it is, when [step] is [SummaryStep.role].
  final String? roleId;

  /// True when the saved game state can't be read back (corrupted, or written by a
  /// version of the app this one doesn't understand). There is nothing to show.
  final bool unreadable;

  const SessionSummary({
    required this.phase,
    required this.nightIndex,
    required this.step,
    this.roleId,
  }) : unreadable = false;

  const SessionSummary.unreadable()
    : phase = JournalPhase.night,
      nightIndex = 0,
      step = SummaryStep.recap,
      roleId = null,
      unreadable = true;
}

/// Hand-written (not codegen): decodes the `sessionJson` blob, which embeds a
/// `GameState` - riverpod_generator can't handle that return type indirectly
/// any more than it can a Drift row.
final sessionSummaryProvider =
    FutureProvider.autoDispose.family<SessionSummary?, int>((ref, gameId) async {
  final game = await ref.watch(gameRepositoryProvider).getGame(gameId);
  final blob = game?.sessionJson;
  if (blob == null) return null;

  try {
    return _summarize(game!, blob);
  } catch (_) {
    // Anything that fails to decode (bad JSON, a missing key, an unknown role) means the
    // saved state is unusable; say so instead of failing the whole card.
    return const SessionSummary.unreadable();
  }
});

SessionSummary _summarize(Game game, String blob) {
  final decoded = jsonDecode(blob) as Map<String, dynamic>;
  final engine = GameStateJson.decode(decoded['engine'] as Map<String, dynamic>);

  if (engine.phase == GamePhase.day) {
    final stage = DayStage.values.asNameMap()[decoded['day']?['stage']] ?? DayStage.recap;
    final step = engine.cascade != null
        ? SummaryStep.chainEffect
        : switch (stage) {
            DayStage.recap => SummaryStep.recap,
            DayStage.growl => SummaryStep.bearGrowl,
            DayStage.captain => SummaryStep.captainElection,
            DayStage.vote || DayStage.secondVote => SummaryStep.villageVote,
            DayStage.done => SummaryStep.dayDone,
          };
    return SessionSummary(phase: JournalPhase.day, nightIndex: engine.nightIndex, step: step);
  }

  final cursor = SessionCursor.fromJson(decoded['cursor'] as Map<String, dynamic>);
  final composition = game.compositionJson ?? const <String, int>{};
  final pickedReserve = game.reserveRolesJson ?? const <String>[];
  final reserveDrawn = composition.containsKey('voleur') && pickedReserve.isEmpty;
  final reserve = reserveDrawn
      ? [for (final id in decoded['drawnReserve'] as List<dynamic>? ?? const []) id as String]
      : pickedReserve;
  final script = buildNightScript(
    engine: engine,
    composition: composition,
    dealtComposition: dealtCompositionOf(composition, reserve, reserveDrawn: reserveDrawn),
    foxAfterWitch: decoded['foxAfterWitch'] == true,
    whiteWolfOddNights: decoded['whiteWolfOdd'] == true,
  );
  final inRoleTurn = cursor.stepIndex < script.steps.length;
  return SessionSummary(
    phase: JournalPhase.night,
    nightIndex: engine.nightIndex,
    step: inRoleTurn ? SummaryStep.role : SummaryStep.nightEnd,
    roleId: inRoleTurn ? script.steps[cursor.stepIndex].role.id : null,
  );
}
