import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/game_status.dart';
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
  }) async {
    final rowsAffected =
        await (_db.update(_db.games)..where((g) => g.id.equals(gameId))).write(
          GamesCompanion(
            playerCount: Value(playerCount),
            compositionJson: Value(roleCounts),
            status: Value(GameStatus.inProgress),
            updatedAt: Value(DateTime.now()),
          ),
        );
    if (rowsAffected == 0) {
      throw GameNotFoundException(gameId);
    }
  }

  @override
  Future<void> discardDraft(int gameId) {
    return (_db.delete(
      _db.games,
    )..where((g) => g.id.equals(gameId) & g.status.equalsValue(GameStatus.setup))).go();
  }
}
