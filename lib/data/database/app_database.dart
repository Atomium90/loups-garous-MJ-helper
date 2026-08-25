import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../models/game_status.dart';
import 'converters/role_counts_converter.dart';
import 'tables/games_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Games])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'loup_garou_mj'));

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;
}
