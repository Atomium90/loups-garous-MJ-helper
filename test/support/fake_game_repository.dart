import 'dart:async';

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

  /// gameId -> roster rows, seatIndex order. Mirrors the Players table.
  final Map<int, List<PlayerRow>> _rosters = {};

  int _nextId = 1;
  int _nextPlayerId = 1;

  // Broadcasts *that something changed*, not the data itself - each watchGames() subscriber
  // re-reads and re-sorts `_games` on every event, matching the interface's own documented
  // contract ("emits an initial snapshot then a new one on every write"). A plain
  // `Stream.value(...)` (this class's original implementation) only emits once at construction
  // and never again, which silently hid a real bug this session: HomeScreen's "Nouvelle partie"
  // button lived inside the widget subtree that gets unmounted the moment the games list
  // updates, and no test caught it until a real device exposed the race.
  final _changes = StreamController<void>.broadcast();

  /// Test-only convenience: every row currently held, insertion order (unsorted).
  List<Game> get allGames => _games.values.toList(growable: false);

  /// Test-only convenience: the roster held for [gameId], seatIndex order.
  List<PlayerRow> rosterOf(int gameId) => List.unmodifiable(_rosters[gameId] ?? const []);

  List<Game> _sortedGames() =>
      _games.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Stream<List<Game>> watchGames() async* {
    yield _sortedGames();
    yield* _changes.stream.map((_) => _sortedGames());
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
    _changes.add(null);
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
      updatedAt: DateTime.now(),
    );
    // Seed a blank roster once, mirroring DriftGameRepository's transaction.
    if ((_rosters[gameId] ?? const []).isEmpty) {
      _rosters[gameId] = [
        for (var seat = 0; seat < playerCount; seat++)
          PlayerRow(
            id: _nextPlayerId++,
            gameId: gameId,
            seatIndex: seat,
            name: '',
            alive: true,
          ),
      ];
    }
    _changes.add(null);
  }

  @override
  Stream<List<PlayerRow>> watchRoster(int gameId) async* {
    yield rosterOf(gameId);
    yield* _changes.stream.map((_) => rosterOf(gameId));
  }

  @override
  Future<List<PlayerRow>> getRoster(int gameId) async => rosterOf(gameId);

  @override
  Future<void> savePlayerNames({required int gameId, required List<String> names}) async {
    final roster = _rosters[gameId] ?? const [];
    if (roster.length != names.length) {
      throw ArgumentError.value(
        names,
        'names',
        'expected ${roster.length} names for game $gameId, got ${names.length}',
      );
    }
    _rosters[gameId] = [
      for (final (i, player) in roster.indexed) player.copyWith(name: names[i]),
    ];
    _changes.add(null);
  }

  @override
  Future<void> startGame(int gameId) async {
    final game = _games[gameId];
    if (game == null) throw GameNotFoundException(gameId);
    _games[gameId] = game.copyWith(
      status: GameStatus.inProgress,
      updatedAt: DateTime.now(),
    );
    _changes.add(null);
  }

  @override
  Future<void> discardDraft(int gameId) async {
    final game = _games[gameId];
    if (game != null && game.status == GameStatus.setup) {
      _games.remove(gameId);
      _rosters.remove(gameId);
      _changes.add(null);
    }
  }
}
