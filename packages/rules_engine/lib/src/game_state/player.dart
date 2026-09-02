import 'death_cause.dart';
import 'game_phase.dart';

class Player {
  final String id;
  final String name;

  /// Mutable via Voleur's swap, or a post-mortem card reveal.
  final String roleId;
  final bool alive;

  /// All three are null while the player is alive, and set together the moment
  /// they die (see [GameState.killPlayer]). A player never comes back to life,
  /// so they are only ever written once.
  final DeathCause? causeOfDeath;
  final int? diedOnNight;
  final GamePhase? diedOnPhase;

  const Player({
    required this.id,
    required this.name,
    required this.roleId,
    this.alive = true,
    this.causeOfDeath,
    this.diedOnNight,
    this.diedOnPhase,
  });

  Player copyWith({
    String? roleId,
    bool? alive,
    DeathCause? causeOfDeath,
    int? diedOnNight,
    GamePhase? diedOnPhase,
  }) => Player(
    id: id,
    name: name,
    roleId: roleId ?? this.roleId,
    alive: alive ?? this.alive,
    causeOfDeath: causeOfDeath ?? this.causeOfDeath,
    diedOnNight: diedOnNight ?? this.diedOnNight,
    diedOnPhase: diedOnPhase ?? this.diedOnPhase,
  );

  @override
  String toString() => 'Player($id, roleId: $roleId, alive: $alive)';
}

class PlayerNotFoundException implements Exception {
  final String playerId;
  PlayerNotFoundException(this.playerId);

  @override
  String toString() => 'PlayerNotFoundException: no player with id "$playerId"';
}
