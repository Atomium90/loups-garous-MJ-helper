import 'package:async/async.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/data/database/app_database.dart';
import 'package:loup_garou_mj/data/database/converters/role_counts_converter.dart';
import 'package:loup_garou_mj/data/models/game_status.dart';
import 'package:loup_garou_mj/data/repositories/drift_game_repository.dart';
import 'package:loup_garou_mj/data/repositories/game_not_found_exception.dart';

void main() {
  group('RoleCountsConverter', () {
    const converter = RoleCountsConverter();

    test('round-trips a role counts map', () {
      const counts = {'loup_garou': 2, 'voyante': 1};
      expect(converter.fromSql(converter.toSql(counts)), counts);
    });

    test('round-trips an empty map', () {
      expect(converter.fromSql(converter.toSql(const {})), <String, int>{});
    });
  });

  late AppDatabase db;
  late DriftGameRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftGameRepository(db);
  });

  tearDown(() => db.close());

  group('createGame', () {
    test('inserts a row with the given player count and GameStatus.setup', () async {
      final id = await repository.createGame(initialPlayerCount: 9);
      final game = await repository.getGame(id);
      expect(game, isNotNull);
      expect(game!.playerCount, 9);
      expect(game.status, GameStatus.setup);
      expect(game.compositionJson, isNull);
    });

    test('defaults to 8 players when not specified', () async {
      final id = await repository.createGame();
      final game = await repository.getGame(id);
      expect(game!.playerCount, 8);
    });

    test('called twice yields two distinct ids', () async {
      final firstId = await repository.createGame();
      final secondId = await repository.createGame();
      expect(firstId, isNot(secondId));
    });
  });

  group('getGame', () {
    test('returns null for a nonexistent id', () async {
      expect(await repository.getGame(999), isNull);
    });
  });

  group('saveComposition', () {
    test('round-trips playerCount, compositionJson and status', () async {
      final id = await repository.createGame();
      await repository.saveComposition(
        gameId: id,
        playerCount: 9,
        roleCounts: const {'loup_garou': 2, 'voyante': 1, 'villageois': 6},
      );

      final game = await repository.getGame(id);
      expect(game!.playerCount, 9);
      expect(game.compositionJson, {'loup_garou': 2, 'voyante': 1, 'villageois': 6});
      expect(game.status, GameStatus.inProgress);
    });

    test('sets updatedAt to roughly now', () async {
      final id = await repository.createGame();
      await repository.saveComposition(gameId: id, playerCount: 8, roleCounts: const {});

      final updatedAt = (await repository.getGame(id))!.updatedAt;
      // Drift's default DateTime column stores unix-epoch seconds, so this
      // can't assert strict ordering against a near-simultaneous prior read
      // (sub-second precision is lost); "close to now" is what's actually
      // observable.
      expect(DateTime.now().difference(updatedAt).inSeconds.abs(), lessThan(5));
    });

    test('throws GameNotFoundException for an unknown id', () {
      expect(
        () => repository.saveComposition(gameId: 999, playerCount: 8, roleCounts: const {}),
        throwsA(isA<GameNotFoundException>()),
      );
    });
  });

  group('discardDraft', () {
    test('deletes a game still in GameStatus.setup', () async {
      final id = await repository.createGame();
      await repository.discardDraft(id);
      expect(await repository.getGame(id), isNull);
    });

    test('does not delete a game that has already been saved', () async {
      final id = await repository.createGame();
      await repository.saveComposition(gameId: id, playerCount: 8, roleCounts: const {});
      await repository.discardDraft(id);
      expect(await repository.getGame(id), isNotNull);
    });
  });

  group('watchGames', () {
    test('emits an initial empty snapshot when there are no games', () async {
      final queue = StreamQueue(repository.watchGames());
      expect(await queue.next, isEmpty);
      await queue.cancel();
    });

    test('emits a new snapshot after createGame', () async {
      final queue = StreamQueue(repository.watchGames());
      expect(await queue.next, isEmpty);

      await repository.createGame();
      expect(await queue.next, hasLength(1));

      await queue.cancel();
    });

    test('emits a new snapshot after saveComposition', () async {
      final id = await repository.createGame();
      final queue = StreamQueue(repository.watchGames());
      expect(await queue.next, hasLength(1));

      await repository.saveComposition(gameId: id, playerCount: 8, roleCounts: const {});
      final afterSave = await queue.next;
      expect(afterSave.single.status, GameStatus.inProgress);

      await queue.cancel();
    });

    test('orders newest first', () async {
      final olderId = await repository.createGame();
      await db
          .update(db.games)
          .replace((await repository.getGame(olderId))!.copyWith(createdAt: DateTime(2020)));

      final newerId = await repository.createGame();
      await db
          .update(db.games)
          .replace((await repository.getGame(newerId))!.copyWith(createdAt: DateTime(2024)));

      final games = await repository.watchGames().first;
      expect(games.map((g) => g.id), [newerId, olderId]);
    });
  });
}
