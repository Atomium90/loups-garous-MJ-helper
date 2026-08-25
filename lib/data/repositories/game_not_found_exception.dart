class GameNotFoundException implements Exception {
  final int gameId;
  GameNotFoundException(this.gameId);

  @override
  String toString() => 'GameNotFoundException: no game with id $gameId';
}
