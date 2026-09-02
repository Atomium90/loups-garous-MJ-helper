import 'package:drift/drift.dart';

import '../../models/game_status.dart';
import '../../models/game_winner.dart';
import '../converters/role_counts_converter.dart';

@DataClassName('Game')
class Games extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Free-text custom label. Null means the display label is derived from
  /// [createdAt] instead (e.g. "Partie du 14 août").
  TextColumn get name => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// Set at creation and again when the composition is saved. Denormalized
  /// (not derived from [compositionJson]): must be meaningful before any
  /// role is picked, and the home screen needs it without decoding JSON.
  IntColumn get playerCount => integer()();

  /// Null means no composition has been chosen yet (fresh draft game).
  TextColumn get compositionJson => text().nullable().map(const RoleCountsConverter())();

  IntColumn get status => intEnum<GameStatus>().withDefault(Constant(GameStatus.setup.index))();

  /// The live game-state snapshot, set once the night starts and rewritten
  /// after every MJ action: `{"engine": <GameState JSON>, "cursor": {...}}`.
  /// Null through setup/composition/naming. This is the source of truth for a
  /// running game (the roster's role/alive columns are only meaningful pre-start).
  TextColumn get sessionJson => text().nullable()();

  /// The outcome the MJ declared on the end-of-game screen. Null while the game is still
  /// running; [GameWinner.none] means it was called off.
  IntColumn get winner => intEnum<GameWinner>().nullable()();

  /// When [status] moved to completed. Null while running.
  DateTimeColumn get endedAt => dateTime().nullable()();
}
