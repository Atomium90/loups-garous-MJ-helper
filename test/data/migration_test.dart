import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/data/database/app_database.dart';
import 'package:loup_garou_mj/data/models/game_status.dart';

import '../generated_migrations/schema.dart';

/// Replays every schema upgrade from the committed snapshots in `drift_schemas/`.
///
/// When the schema changes: bump `schemaVersion` in `AppDatabase`, then
/// `dart run drift_dev schema dump lib/data/database/app_database.dart drift_schemas/` and
/// `dart run drift_dev schema generate drift_schemas/ test/generated_migrations/`.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('migrating to the current schema', () {
    // Each snapshot must end up exactly at the schema the code declares: tables,
    // columns, constraints and indexes included.
    for (final fromVersion in GeneratedHelper.versions) {
      test('from version $fromVersion', () async {
        final schema = await verifier.schemaAt(fromVersion);
        final db = AppDatabase.forTesting(schema.newConnection());
        addTearDown(db.close);

        await verifier.migrateAndValidate(db, db.schemaVersion);
      });
    }
  });

  group('keeping the existing data', () {
    test('a game from the first schema survives with the new columns empty', () async {
      final schema = await verifier.schemaAt(1);
      schema.rawDatabase.execute(
        'INSERT INTO games (name, player_count, composition_json, status) '
        '''VALUES ('Soirée du samedi', 8, '{"loup_garou":2,"villageois":6}', 1)''',
      );
      final db = AppDatabase.forTesting(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, db.schemaVersion);

      final game = await db.select(db.games).getSingle();
      expect(game.name, 'Soirée du samedi');
      expect(game.playerCount, 8);
      expect(game.compositionJson, {'loup_garou': 2, 'villageois': 6});
      expect(game.status, GameStatus.inProgress);
      expect(game.sessionJson, isNull);
      expect(game.winner, isNull);
      expect(game.endedAt, isNull);
      expect(game.reserveRolesJson, isNull);
    });

    test('a roster and a journal from schema 3 survive', () async {
      final schema = await verifier.schemaAt(3);
      final raw = schema.rawDatabase;
      raw.execute(
        'INSERT INTO games (name, player_count, status, session_json) '
        '''VALUES ('En cours', 8, 1, '{"engine":{}}')''',
      );
      raw.execute(
        "INSERT INTO players (game_id, seat_index, name) VALUES (1, 0, 'Alice'), (1, 1, 'Bob')",
      );
      raw.execute(
        'INSERT INTO night_log (game_id, seq, phase_label, icon_name, line) '
        '''VALUES (1, 1, 'NUIT 1', 'wolves', 'Les Loups désignent Bob')''',
      );
      final db = AppDatabase.forTesting(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, db.schemaVersion);

      final game = await db.select(db.games).getSingle();
      expect(game.sessionJson, '{"engine":{}}');
      final players = await (db.select(db.players)
            ..orderBy([(p) => OrderingTerm.asc(p.seatIndex)]))
          .get();
      expect(players.map((p) => p.name), ['Alice', 'Bob']);
      final journal = await db.select(db.nightLog).getSingle();
      expect(journal.line, 'Les Loups désignent Bob');
    });

    test('deleting a migrated game still cascades to its roster and journal', () async {
      final schema = await verifier.schemaAt(3);
      final raw = schema.rawDatabase;
      raw.execute("INSERT INTO games (player_count, status) VALUES (8, 1)");
      raw.execute("INSERT INTO players (game_id, seat_index, name) VALUES (1, 0, 'Alice')");
      raw.execute(
        'INSERT INTO night_log (game_id, seq, phase_label, icon_name, line) '
        "VALUES (1, 1, 'NUIT 1', 'wolves', 'x')",
      );
      final db = AppDatabase.forTesting(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, db.schemaVersion);

      await db.delete(db.games).go();

      expect(await db.select(db.players).get(), isEmpty);
      expect(await db.select(db.nightLog).get(), isEmpty);
    });
  });
}
