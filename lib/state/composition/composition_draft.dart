import 'package:freezed_annotation/freezed_annotation.dart';

import '../../data/database/app_database.dart';

part 'composition_draft.freezed.dart';

/// Local draft state for the composition screen: mutated by chip taps and
/// the player-count stepper, only persisted when the MJ commits it.
@freezed
abstract class CompositionDraft with _$CompositionDraft {
  const CompositionDraft._();

  const factory CompositionDraft({
    required int gameId,
    required int playerCount,
    required Map<String, int> roleCounts,
  }) = _CompositionDraft;

  factory CompositionDraft.fromGame(Game game) => CompositionDraft(
    gameId: game.id,
    playerCount: game.playerCount,
    roleCounts: game.compositionJson ?? const {},
  );

  int get assignedCount => roleCounts.values.fold(0, (a, b) => a + b);
  int get remaining => playerCount - assignedCount;
  bool get isValid => remaining >= 0;
}
