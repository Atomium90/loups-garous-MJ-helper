import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../data/database/app_database.dart';
import '../providers/game_repository_provider.dart';
import 'night_script.dart';
import 'session_cursor.dart';

/// The resume line on Home's "en cours" card, e.g. "Nuit 1 · les Loups" or
/// "Jour 1 · récap". Null before the night starts (the card then shows a flat
/// fallback).
class SessionSummary {
  final String phaseLabel;
  final String stepLabel;

  /// True when the saved game state can't be read back (corrupted, or written by a
  /// version of the app this one doesn't understand). There is no line to show.
  final bool unreadable;

  const SessionSummary({required this.phaseLabel, required this.stepLabel})
    : unreadable = false;

  const SessionSummary.unreadable() : phaseLabel = '', stepLabel = '', unreadable = true;

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
    final stepLabel = engine.cascade != null
        ? 'effet en chaîne'
        : switch (decoded['day']?['stage'] as String?) {
            'captain' => 'élection du Capitaine',
            'vote' => 'vote du village',
            'done' => 'fin du jour',
            _ => 'récap',
          };
    return SessionSummary(phaseLabel: 'Jour ${engine.nightIndex}', stepLabel: stepLabel);
  }

  final cursor = SessionCursor.fromJson(decoded['cursor'] as Map<String, dynamic>);
  final script = buildNightScript(
    engine: engine,
    composition: game.compositionJson ?? const {},
  );
  final stepLabel = cursor.stepIndex < script.steps.length
      ? script.steps[cursor.stepIndex].role.name
      : 'fin de la nuit';
  return SessionSummary(phaseLabel: 'Nuit ${engine.nightIndex}', stepLabel: stepLabel);
}
