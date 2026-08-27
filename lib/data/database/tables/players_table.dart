import 'package:drift/drift.dart';

import 'games_table.dart';

/// One seat at the table. Rows are created blank (name `''`) the moment a
/// composition is saved (see [GameRepository.saveComposition]), sized to the
/// game's player count, then named on the A1 screen.
///
/// `@DataClassName('PlayerRow')`, not `'Player'`: `rules_engine` already exports
/// a `Player` (the in-memory game-state player), and both types can end up
/// imported into the same file at the repository/state layer.
@DataClassName('PlayerRow')
class Players extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Deleting a game deletes its roster (needs `PRAGMA foreign_keys = ON`,
  /// enabled in [AppDatabase]'s migration strategy - drift doesn't enforce
  /// foreign keys by default).
  IntColumn get gameId => integer().references(Games, #id, onDelete: KeyAction.cascade)();

  /// 0-based. Doubles as the deal order and the display order in every roster
  /// list, so it's the stable key `savePlayerNames` writes against.
  IntColumn get seatIndex => integer()();

  /// Empty until the MJ types it on A1.
  TextColumn get name => text().withDefault(const Constant(''))();

  /// Assigned during night 1 (or manual assignment) - Phase 4. Unwritten this
  /// far, declared now so adding it doesn't need a schema migration later.
  TextColumn get roleId => text().nullable()();

  BoolColumn get alive => boolean().withDefault(const Constant(true))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {gameId, seatIndex},
  ];
}
