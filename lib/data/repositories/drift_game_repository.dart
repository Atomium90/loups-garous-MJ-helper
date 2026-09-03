import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/game_status.dart';
import '../models/game_winner.dart';
import '../models/night_log_entry.dart';
import 'game_not_found_exception.dart';
import 'game_repository.dart';

class DriftGameRepository implements GameRepository {
  final AppDatabase _db;

  DriftGameRepository(this._db);

  @override
  Stream<List<Game>> watchGames() {
    final query = _db.select(_db.games)
      ..orderBy([(g) => OrderingTerm.desc(g.createdAt)]);
    return query.watch();
  }

  @override
  Future<Game?> getGame(int id) {
    final query = _db.select(_db.games)..where((g) => g.id.equals(id));
    return query.getSingleOrNull();
  }

  @override
  Future<int> createGame({int initialPlayerCount = 8}) {
    return _db.into(_db.games).insert(GamesCompanion.insert(playerCount: initialPlayerCount));
  }

  @override
  Future<void> saveComposition({
    required int gameId,
    required int playerCount,
    required Map<String, int> roleCounts,
    List<String> reserveRoleIds = const [],
  }) {
    return _db.transaction(() async {
      final rowsAffected =
          await (_db.update(_db.games)..where((g) => g.id.equals(gameId))).write(
            GamesCompanion(
              playerCount: Value(playerCount),
              compositionJson: Value(roleCounts),
              reserveRolesJson: Value(reserveRoleIds.isEmpty ? null : reserveRoleIds),
              updatedAt: Value(DateTime.now()),
            ),
          );
      if (rowsAffected == 0) {
        throw GameNotFoundException(gameId);
      }

      final existing = await (_db.select(
        _db.players,
      )..where((p) => p.gameId.equals(gameId))).get();
      if (existing.isEmpty) {
        await _db.batch((batch) {
          batch.insertAll(_db.players, [
            for (var seat = 0; seat < playerCount; seat++)
              PlayersCompanion.insert(gameId: gameId, seatIndex: seat),
          ]);
        });
      }
    });
  }

  @override
  Stream<List<PlayerRow>> watchRoster(int gameId) {
    final query = _db.select(_db.players)
      ..where((p) => p.gameId.equals(gameId))
      ..orderBy([(p) => OrderingTerm.asc(p.seatIndex)]);
    return query.watch();
  }

  @override
  Future<List<PlayerRow>> getRoster(int gameId) {
    final query = _db.select(_db.players)
      ..where((p) => p.gameId.equals(gameId))
      ..orderBy([(p) => OrderingTerm.asc(p.seatIndex)]);
    return query.get();
  }

  @override
  Future<void> savePlayerNames({required int gameId, required List<String> names}) {
    return _db.transaction(() async {
      final roster = await getRoster(gameId);
      if (roster.length != names.length) {
        throw ArgumentError.value(
          names,
          'names',
          'expected ${roster.length} names for game $gameId, got ${names.length}',
        );
      }
      for (final (i, player) in roster.indexed) {
        await (_db.update(_db.players)..where((p) => p.id.equals(player.id))).write(
          PlayersCompanion(name: Value(names[i])),
        );
      }
    });
  }

  @override
  Future<void> assignRoles({required List<int> playerRowIds, required String roleId}) {
    if (playerRowIds.isEmpty) return Future.value();
    return (_db.update(_db.players)..where((p) => p.id.isIn(playerRowIds))).write(
      PlayersCompanion(roleId: Value(roleId)),
    );
  }

  @override
  Future<void> startGame(int gameId) async {
    final rowsAffected =
        await (_db.update(_db.games)..where((g) => g.id.equals(gameId))).write(
          GamesCompanion(
            status: const Value(GameStatus.inProgress),
            updatedAt: Value(DateTime.now()),
          ),
        );
    if (rowsAffected == 0) {
      throw GameNotFoundException(gameId);
    }
  }

  @override
  Future<void> endGame({required int gameId, required GameWinner winner}) async {
    final now = DateTime.now();
    final rowsAffected =
        await (_db.update(_db.games)..where((g) => g.id.equals(gameId))).write(
          GamesCompanion(
            status: const Value(GameStatus.completed),
            winner: Value(winner),
            endedAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    if (rowsAffected == 0) {
      throw GameNotFoundException(gameId);
    }
  }

  @override
  Future<void> saveSession({required int gameId, required String sessionJson}) async {
    final rowsAffected =
        await (_db.update(_db.games)..where((g) => g.id.equals(gameId))).write(
          GamesCompanion(
            sessionJson: Value(sessionJson),
            updatedAt: Value(DateTime.now()),
          ),
        );
    if (rowsAffected == 0) {
      throw GameNotFoundException(gameId);
    }
  }

  @override
  Future<void> appendNightLog({required int gameId, required List<NightLogEntry> entries}) {
    if (entries.isEmpty) return Future.value();
    return _db.transaction(() async {
      final maxSeq =
          await (_db.selectOnly(_db.nightLog)
                ..addColumns([_db.nightLog.seq.max()])
                ..where(_db.nightLog.gameId.equals(gameId)))
              .map((row) => row.read(_db.nightLog.seq.max()))
              .getSingleOrNull();
      var seq = (maxSeq ?? 0) + 1;
      await _db.batch((batch) {
        for (final entry in entries) {
          batch.insert(
            _db.nightLog,
            NightLogCompanion.insert(
              gameId: gameId,
              seq: seq++,
              phaseLabel: entry.phaseLabel,
              iconName: entry.iconName,
              line: entry.line,
            ),
          );
        }
      });
    });
  }

  @override
  Stream<List<NightLogRow>> watchNightLog(int gameId) {
    final query = _db.select(_db.nightLog)
      ..where((e) => e.gameId.equals(gameId))
      ..orderBy([(e) => OrderingTerm.desc(e.seq)]);
    return query.watch();
  }

  @override
  Future<void> discardDraft(int gameId) {
    return (_db.delete(
      _db.games,
    )..where((g) => g.id.equals(gameId) & g.status.equalsValue(GameStatus.setup))).go();
  }
}
