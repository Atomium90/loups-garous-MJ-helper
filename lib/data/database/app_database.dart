import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../models/game_status.dart';
import 'converters/role_counts_converter.dart';
import 'tables/games_table.dart';
import 'tables/players_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Games, Players])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'loup_garou_mj'));

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(players);
      }
    },
    // drift doesn't enable foreign-key enforcement by default; without this the
    // Players.gameId `onDelete: cascade` silently doesn't fire.
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
