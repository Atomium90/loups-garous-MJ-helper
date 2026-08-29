import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rules_engine/rules_engine.dart';

import '../providers/game_repository_provider.dart';
import 'night_script.dart';
import 'session_cursor.dart';

/// The resume line on Home's "en cours" card, e.g. "Nuit 1 · les Loups" or
/// "Jour 1 · récap". Null before the night starts (the card then shows a flat
/// fallback).
class SessionSummary {
  final String phaseLabel;
  final String stepLabel;

  const SessionSummary({required this.phaseLabel, required this.stepLabel});

  String get line => '$phaseLabel · $stepLabel';
}

/// Hand-written (not codegen): decodes the `sessionJson` blob, which embeds a
/// `GameState` - riverpod_generator can't handle that return type indirectly
/// any more than it can a Drift row.
final sessionSummaryProvider =
    FutureProvider.autoDispose.family<SessionSummary?, int>((ref, gameId) async {
  final game = await ref.watch(gameRepositoryProvider).getGame(gameId);
  final blob = game?.sessionJson;
  if (blob == null) return null;

  final decoded = jsonDecode(blob) as Map<String, dynamic>;
  final engine = GameStateJson.decode(decoded['engine'] as Map<String, dynamic>);

  if (engine.phase == GamePhase.day) {
    return SessionSummary(phaseLabel: 'Jour ${engine.nightIndex}', stepLabel: 'récap');
  }

  final cursor = SessionCursor.fromJson(decoded['cursor'] as Map<String, dynamic>);
  final script = buildNightScript(
    engine: engine,
    composition: game!.compositionJson ?? const {},
  );
  final stepLabel = cursor.stepIndex < script.steps.length
      ? script.steps[cursor.stepIndex].role.name
      : 'fin de la nuit';
  return SessionSummary(phaseLabel: 'Nuit ${engine.nightIndex}', stepLabel: stepLabel);
});
