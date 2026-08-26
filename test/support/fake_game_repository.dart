import 'package:drift/drift.dart';
import 'package:loup_garou_mj/data/database/app_database.dart';
import 'package:loup_garou_mj/data/models/game_status.dart';
import 'package:loup_garou_mj/data/repositories/game_not_found_exception.dart';
import 'package:loup_garou_mj/data/repositories/game_repository.dart';

/// In-memory [GameRepository], shared by any test that needs one instead of a real Drift
/// database. [initialGames] seeds arbitrary rows directly (status, createdAt, name) - useful for
/// scenarios [createGame] can't produce on its own (e.g. a `completed` game, since nothing in
/// this app can actually reach that status yet).
class FakeGameRepository implements GameRepository {
  FakeGameRepository({List<Game> initialGames = const []}) {
    for (final game in initialGames) {
      _games[game.id] = game;
      _nextId = _nextId > game.id ? _nextId : game.id + 1;
    }
  }

  final Map<int, Game> _games = {};
  int _nextId = 1;

  /// Test-only convenience: every row currently held, insertion order (unsorted).
  List<Game> get allGames => _games.values.toList(growable: false);

  @override
  Stream<List<Game>> watchGames() {
    // Mirrors DriftGameRepository.watchGames()'s `OrderingTerm.desc(createdAt)`, so tests that
    // rely on "most recent first" (e.g. Accueil's En cours ordering) see real production
    // behaviour, not just insertion order.
    final sorted = _games.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Stream.value(sorted);
  }

  @override
  Future<Game?> getGame(int id) async => _games[id];

  @override
  Future<int> createGame({int initialPlayerCount = 8}) async {
    final id = _nextId++;
    _games[id] = Game(
      id: id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      playerCount: initialPlayerCount,
      status: GameStatus.setup,
    );
    return id;
  }

  @override
  Future<void> saveComposition({
    required int gameId,
    required int playerCount,
    required Map<String, int> roleCounts,
  }) async {
    final game = _games[gameId];
    if (game == null) throw GameNotFoundException(gameId);
    _games[gameId] = game.copyWith(
      playerCount: playerCount,
      compositionJson: Value(roleCounts),
      status: GameStatus.inProgress,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> discardDraft(int gameId) async {
    final game = _games[gameId];
    if (game != null && game.status == GameStatus.setup) {
      _games.remove(gameId);
    }
  }
}
