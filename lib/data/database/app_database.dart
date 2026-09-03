import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../models/game_status.dart';
import '../models/game_winner.dart';
import 'converters/role_counts_converter.dart';
import 'converters/string_list_converter.dart';
import 'tables/games_table.dart';
import 'tables/night_log_table.dart';
import 'tables/players_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Games, Players, NightLog])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'loup_garou_mj'));

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(players);
      }
      if (from < 3) {
        await m.addColumn(games, games.sessionJson);
        await m.createTable(nightLog);
      }
      if (from < 4) {
        await m.addColumn(games, games.winner);
        await m.addColumn(games, games.endedAt);
      }
      if (from < 5) {
        await m.addColumn(games, games.reserveRolesJson);
      }
    },
    // drift doesn't enable foreign-key enforcement by default; without this the
    // `onDelete: cascade` on Players.gameId / NightLog.gameId silently doesn't fire.
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
