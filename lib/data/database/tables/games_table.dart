import 'package:drift/drift.dart';

import '../../models/game_status.dart';
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
}
