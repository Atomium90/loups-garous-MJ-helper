/// Night or day. Lives in its own file so [Player] can carry a `diedOnPhase`
/// without importing `game_state.dart` (which imports `player.dart` - a cycle).
enum GamePhase { night, day }
