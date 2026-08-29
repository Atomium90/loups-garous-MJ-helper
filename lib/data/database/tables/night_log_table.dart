import 'package:drift/drift.dart';

import 'games_table.dart';

/// One line of the in-game journal (the JR screen): pre-rendered French text,
/// not structured events. This is a display log, never the source of truth for
/// game state - that's the `sessionJson` snapshot on [Games].
@DataClassName('NightLogRow')
class NightLog extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get gameId => integer().references(Games, #id, onDelete: KeyAction.cascade)();

  /// Per-game monotonic order. The Journal renders newest-first (descending).
  IntColumn get seq => integer()();

  /// Uppercase phase header the line groups under, e.g. "NUIT 1", "JOUR 1".
  TextColumn get phaseLabel => text()();

  /// Semantic key the UI maps to an [AppIcons] entry (e.g. "wolves", "flask").
  TextColumn get iconName => text()();

  /// The line itself, e.g. "Les Loups désignent Théo, sauvé". Named `line`, not
  /// `text`, because `text` collides with drift's `Table.text()` column builder.
  TextColumn get line => text()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
