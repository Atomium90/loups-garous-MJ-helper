import 'package:drift/drift.dart';

import 'games_table.dart';

/// One line of the in-game journal. This is a display log, never the source of truth for
/// game state - that's the `sessionJson` snapshot on [Games].
///
/// Lines written since schema 6 are structured ([kind] + [argsJson] under a
/// [phase] / [phaseIndex] header) and rendered in the app's language. Older lines hold
/// pre-rendered French text in [phaseLabel] / [line], and [kind] is null: they are shown
/// as they were written.
@DataClassName('NightLogRow')
class NightLog extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get gameId => integer().references(Games, #id, onDelete: KeyAction.cascade)();

  /// Per-game monotonic order. The Journal renders newest-first (descending).
  IntColumn get seq => integer()();

  /// Legacy French phase header ("NUIT 1", "JOUR 1"). Empty on structured lines, which
  /// use [phase] and [phaseIndex] instead; kept NOT NULL so the table needn't be rebuilt.
  TextColumn get phaseLabel => text()();

  /// Semantic key the UI maps to an [AppIcons] entry (e.g. "wolves", "flask").
  TextColumn get iconName => text()();

  /// The legacy French line, e.g. "Les Loups désignent Théo". Empty on structured lines.
  /// Named `line`, not `text`, because `text` collides with drift's `Table.text()` column
  /// builder.
  TextColumn get line => text()();

  /// What happened, as a `JournalKind` name. Null on lines written before schema 6.
  TextColumn get kind => text().nullable()();

  /// The JSON object of values the [kind]'s sentence needs (player names, a role id).
  TextColumn get argsJson => text().nullable()();

  /// Which half of the game the line belongs to, as a `JournalPhase` name ("night" or
  /// "day"). Null on lines written before schema 6.
  TextColumn get phase => text().nullable()();

  /// The night number the [phase] header counts (night 1, day 1, night 2, ...).
  IntColumn get phaseIndex => integer().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
