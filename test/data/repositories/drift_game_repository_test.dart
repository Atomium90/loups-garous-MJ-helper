import 'package:async/async.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/data/database/app_database.dart';
import 'package:loup_garou_mj/data/database/converters/role_counts_converter.dart';
import 'package:loup_garou_mj/data/models/game_status.dart';
import 'package:loup_garou_mj/data/models/game_winner.dart';
import 'package:loup_garou_mj/data/models/night_log_entry.dart';
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
    test('round-trips playerCount and compositionJson, leaves status at setup', () async {
      final id = await repository.createGame();
      await repository.saveComposition(
        gameId: id,
        playerCount: 9,
        roleCounts: const {'loup_garou': 2, 'voyante': 1, 'villageois': 6},
      );

      final game = await repository.getGame(id);
      expect(game!.playerCount, 9);
      expect(game.compositionJson, {'loup_garou': 2, 'voyante': 1, 'villageois': 6});
      // Naming and the deal are still setup; only startGame flips it.
      expect(game.status, GameStatus.setup);
    });

    test('seeds a blank roster sized to playerCount', () async {
      final id = await repository.createGame();
      await repository.saveComposition(gameId: id, playerCount: 6, roleCounts: const {});

      final roster = await repository.getRoster(id);
      expect(roster, hasLength(6));
      expect(roster.map((p) => p.seatIndex), [0, 1, 2, 3, 4, 5]);
      expect(roster.every((p) => p.name.isEmpty), isTrue);
      expect(roster.every((p) => p.alive), isTrue);
    });

    test('called twice does not re-seed or duplicate the roster', () async {
      final id = await repository.createGame();
      await repository.saveComposition(gameId: id, playerCount: 6, roleCounts: const {});
      await repository.savePlayerNames(
        gameId: id,
        names: const ['Ana', 'Bo', 'Cy', 'Di', 'Ed', 'Fi'],
      );

      await repository.saveComposition(gameId: id, playerCount: 6, roleCounts: const {});

      final roster = await repository.getRoster(id);
      expect(roster, hasLength(6));
      expect(roster.map((p) => p.name), ['Ana', 'Bo', 'Cy', 'Di', 'Ed', 'Fi']);
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

    test('round-trips the Voleur reserve role ids', () async {
      final id = await repository.createGame();
      await repository.saveComposition(
        gameId: id,
        playerCount: 8,
        roleCounts: const {'voleur': 1, 'loup_garou': 2, 'villageois': 5},
        reserveRoleIds: const ['chasseur', 'villageois'],
      );

      expect((await repository.getGame(id))!.reserveRolesJson, ['chasseur', 'villageois']);
    });

    test('stores null reserve when none is given, and clears it on re-save', () async {
      final id = await repository.createGame();
      await repository.saveComposition(
        gameId: id,
        playerCount: 8,
        roleCounts: const {'voleur': 1, 'villageois': 7},
        reserveRoleIds: const ['chasseur', 'cupidon'],
      );
      await repository.saveComposition(
        gameId: id,
        playerCount: 8,
        roleCounts: const {'villageois': 8},
      );

      expect((await repository.getGame(id))!.reserveRolesJson, isNull);
    });
  });

  group('savePlayerNames', () {
    test('writes names onto the roster in seat order', () async {
      final id = await repository.createGame();
      await repository.saveComposition(gameId: id, playerCount: 3, roleCounts: const {});

      await repository.savePlayerNames(gameId: id, names: const ['Camille', 'Julien', 'Noa']);

      final roster = await repository.getRoster(id);
      expect(roster.map((p) => p.name), ['Camille', 'Julien', 'Noa']);
    });

    test('throws ArgumentError when the name count does not match the roster', () async {
      final id = await repository.createGame();
      await repository.saveComposition(gameId: id, playerCount: 3, roleCounts: const {});

      expect(
        () => repository.savePlayerNames(gameId: id, names: const ['Camille', 'Julien']),
        throwsArgumentError,
      );
    });
  });

  group('startGame', () {
    test('moves the game from setup to inProgress', () async {
      final id = await repository.createGame();
      await repository.saveComposition(gameId: id, playerCount: 8, roleCounts: const {});
      expect((await repository.getGame(id))!.status, GameStatus.setup);

      await repository.startGame(id);
      expect((await repository.getGame(id))!.status, GameStatus.inProgress);
    });

    test('throws GameNotFoundException for an unknown id', () {
      expect(() => repository.startGame(999), throwsA(isA<GameNotFoundException>()));
    });
  });

  group('endGame', () {
    test('marks the game completed with the declared winner and an endedAt', () async {
      final id = await repository.createGame();
      await repository.saveComposition(gameId: id, playerCount: 8, roleCounts: const {});
      await repository.startGame(id);

      await repository.endGame(gameId: id, winner: GameWinner.wolves);

      final game = await repository.getGame(id);
      expect(game!.status, GameStatus.completed);
      expect(game.winner, GameWinner.wolves);
      expect(DateTime.now().difference(game.endedAt!).inSeconds.abs(), lessThan(5));
    });

    test('leaves the session snapshot intact for the past-game recap', () async {
      final id = await repository.createGame();
      await repository.saveSession(gameId: id, sessionJson: '{"engine":1}');
      await repository.endGame(gameId: id, winner: GameWinner.village);
      expect((await repository.getGame(id))!.sessionJson, '{"engine":1}');
    });

    test('a completed game still shows up newest-first in watchGames', () async {
      final id = await repository.createGame();
      await repository.endGame(gameId: id, winner: GameWinner.none);
      final games = await repository.watchGames().first;
      expect(games.single.id, id);
      expect(games.single.winner, GameWinner.none);
    });

    test('throws GameNotFoundException for an unknown id', () {
      expect(
        () => repository.endGame(gameId: 999, winner: GameWinner.village),
        throwsA(isA<GameNotFoundException>()),
      );
    });
  });

  group('watchRoster', () {
    test('emits the seeded roster then re-emits after savePlayerNames', () async {
      final id = await repository.createGame();
      await repository.saveComposition(gameId: id, playerCount: 2, roleCounts: const {});

      final queue = StreamQueue(repository.watchRoster(id));
      expect((await queue.next).map((p) => p.name), ['', '']);

      await repository.savePlayerNames(gameId: id, names: const ['Lina', 'Théo']);
      expect((await queue.next).map((p) => p.name), ['Lina', 'Théo']);

      await queue.cancel();
    });
  });

  group('assignRoles', () {
    test('writes a role onto the given roster rows only', () async {
      final id = await repository.createGame();
      await repository.saveComposition(gameId: id, playerCount: 4, roleCounts: const {});
      final roster = await repository.getRoster(id);

      await repository.assignRoles(
        playerRowIds: [roster[1].id, roster[3].id],
        roleId: 'loup_garou',
      );

      final after = await repository.getRoster(id);
      expect(after.map((p) => p.roleId), [null, 'loup_garou', null, 'loup_garou']);
    });
  });

  group('saveSession', () {
    test('round-trips the snapshot blob onto Game.sessionJson', () async {
      final id = await repository.createGame();
      await repository.saveSession(gameId: id, sessionJson: '{"engine":1}');
      expect((await repository.getGame(id))!.sessionJson, '{"engine":1}');
    });

    test('throws GameNotFoundException for an unknown id', () {
      expect(
        () => repository.saveSession(gameId: 999, sessionJson: '{}'),
        throwsA(isA<GameNotFoundException>()),
      );
    });
  });

  group('nightLog', () {
    test('appendNightLog assigns increasing per-game seq across calls', () async {
      final id = await repository.createGame();
      await repository.appendNightLog(
        gameId: id,
        entries: const [
          NightLogEntry(phaseLabel: 'NUIT 1', iconName: 'wolves', line: 'Les Loups désignent Théo'),
        ],
      );
      await repository.appendNightLog(
        gameId: id,
        entries: const [
          NightLogEntry(phaseLabel: 'NUIT 1', iconName: 'flask', line: 'La Sorcière empoisonne Noa'),
          NightLogEntry(phaseLabel: 'JOUR 1', iconName: 'sun', line: 'Le jour se lève'),
        ],
      );

      final rows = await (db.select(db.nightLog)
            ..where((e) => e.gameId.equals(id))
            ..orderBy([(e) => OrderingTerm.asc(e.seq)]))
          .get();
      expect(rows.map((r) => r.seq), [1, 2, 3]);
      expect(rows.map((r) => r.line), [
        'Les Loups désignent Théo',
        'La Sorcière empoisonne Noa',
        'Le jour se lève',
      ]);
    });

    test('watchNightLog streams newest-first and re-emits on append', () async {
      final id = await repository.createGame();
      final queue = StreamQueue(repository.watchNightLog(id));
      expect(await queue.next, isEmpty);

      await repository.appendNightLog(
        gameId: id,
        entries: const [
          NightLogEntry(phaseLabel: 'NUIT 1', iconName: 'wolves', line: 'un'),
          NightLogEntry(phaseLabel: 'NUIT 1', iconName: 'flask', line: 'deux'),
        ],
      );
      expect((await queue.next).map((r) => r.line), ['deux', 'un']);

      await queue.cancel();
    });

    test('deleting a game cascades its night-log rows', () async {
      final id = await repository.createGame();
      await repository.appendNightLog(
        gameId: id,
        entries: const [NightLogEntry(phaseLabel: 'NUIT 1', iconName: 'wolves', line: 'x')],
      );

      await repository.discardDraft(id);

      final orphans = await (db.select(db.nightLog)..where((e) => e.gameId.equals(id))).get();
      expect(orphans, isEmpty);
    });
  });

  group('discardDraft', () {
    test('deletes a game still in GameStatus.setup', () async {
      final id = await repository.createGame();
      await repository.discardDraft(id);
      expect(await repository.getGame(id), isNull);
    });

    test('a composed-but-not-started game is still a setup draft: deleted, roster cascades', () async {
      final id = await repository.createGame();
      await repository.saveComposition(gameId: id, playerCount: 4, roleCounts: const {});

      await repository.discardDraft(id);

      expect(await repository.getGame(id), isNull);
      final orphanRows = await (db.select(db.players)..where((p) => p.gameId.equals(id))).get();
      expect(orphanRows, isEmpty);
    });

    test('does not delete a game that has been started', () async {
      final id = await repository.createGame();
      await repository.saveComposition(gameId: id, playerCount: 8, roleCounts: const {});
      await repository.startGame(id);
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
      expect(afterSave.single.compositionJson, isNotNull);

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
