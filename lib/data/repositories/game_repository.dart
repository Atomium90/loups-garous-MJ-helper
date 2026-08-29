import '../database/app_database.dart';
import '../models/night_log_entry.dart';

abstract class GameRepository {
  /// Reactive: emits an initial snapshot then a new one on every write.
  /// Newest games first.
  Stream<List<Game>> watchGames();

  Future<Game?> getGame(int id);

  /// Inserts a new row in GameStatus.setup. Returns the new game's id.
  Future<int> createGame({int initialPlayerCount = 8});

  /// The single write for "Lancer la partie": persists playerCount and
  /// roleCounts, and - in the same transaction - seeds [playerCount] blank
  /// Players rows (seatIndex 0..N-1, empty name) if the game has no roster
  /// yet. The game stays in GameStatus.setup: naming (A1) and the deal (A2)
  /// are still setup, only startGame flips it to inProgress.
  Future<void> saveComposition({
    required int gameId,
    required int playerCount,
    required Map<String, int> roleCounts,
  });

  /// Reactive roster for one game, ordered by seatIndex.
  Stream<List<PlayerRow>> watchRoster(int gameId);

  /// One-shot roster for one game, ordered by seatIndex.
  Future<List<PlayerRow>> getRoster(int gameId);

  /// Writes [names] (in seatIndex order) onto the existing roster rows. The
  /// list length must equal the roster size, or an [ArgumentError] is thrown.
  Future<void> savePlayerNames({required int gameId, required List<String> names});

  /// Writes [roleId] onto the roster rows for [playerRowIds] - what the A1
  /// identification step records as each role wakes on night 1.
  Future<void> assignRoles({required List<int> playerRowIds, required String roleId});

  /// "Commencer la nuit 1": moves the game from setup to inProgress. Kept
  /// generic so it can later also seed the night phase/step.
  Future<void> startGame(int gameId);

  /// Persists the live game-state snapshot blob onto [Game.sessionJson].
  Future<void> saveSession({required int gameId, required String sessionJson});

  /// Appends journal lines, assigning each the next per-game [NightLogRow.seq].
  Future<void> appendNightLog({required int gameId, required List<NightLogEntry> entries});

  /// Reactive journal for one game, most recent first (descending seq).
  Stream<List<NightLogRow>> watchNightLog(int gameId);

  /// Deletes a game, but only if it's still GameStatus.setup (abandoned
  /// draft cleanup, not a general-purpose delete). Its roster and journal
  /// rows cascade.
  Future<void> discardDraft(int gameId);
}
