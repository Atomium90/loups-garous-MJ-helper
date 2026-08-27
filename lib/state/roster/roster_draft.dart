import 'package:freezed_annotation/freezed_annotation.dart';

import '../../data/database/app_database.dart';

part 'roster_draft.freezed.dart';

/// Local draft state for the A1 "Les joueurs" screen: [names] in seat order,
/// mutated as the MJ types, only persisted when they tap "Continuer".
/// Mirrors [CompositionDraft]'s draft-then-commit shape.
@freezed
abstract class RosterDraft with _$RosterDraft {
  const RosterDraft._();

  const factory RosterDraft({
    required int gameId,
    required List<String> names,
  }) = _RosterDraft;

  factory RosterDraft.fromRoster(int gameId, List<PlayerRow> rows) =>
      RosterDraft(gameId: gameId, names: rows.map((r) => r.name).toList());

  int get namedCount => names.where((n) => n.trim().isNotEmpty).length;
  int get total => names.length;

  /// Every seat has a non-blank name - the only gate on "Continuer".
  bool get allNamed => total > 0 && namedCount == total;
}
