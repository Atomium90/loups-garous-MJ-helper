import '../database/app_database.dart';

abstract class GameRepository {
  /// Reactive: emits an initial snapshot then a new one on every write.
  /// Newest games first.
  Stream<List<Game>> watchGames();

  Future<Game?> getGame(int id);

  /// Inserts a new row in GameStatus.setup. Returns the new game's id.
  Future<int> createGame({int initialPlayerCount = 8});

  /// The single write for "Lancer la partie": persists playerCount and
  /// roleCounts together, sets status to GameStatus.inProgress.
  Future<void> saveComposition({
    required int gameId,
    required int playerCount,
    required Map<String, int> roleCounts,
  });

  /// Deletes a game, but only if it's still GameStatus.setup (abandoned
  /// draft cleanup, not a general-purpose delete).
  Future<void> discardDraft(int gameId);
}
