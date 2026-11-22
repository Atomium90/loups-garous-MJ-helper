import '../models/team.dart';
import 'death_cause.dart';
import 'game_phase.dart';

/// A condition a player carries on top of their role. Stored by name: append new ones, never
/// rename.
enum PlayerStatus {
  /// Turned into a werewolf by the Infect Père des Loups: keeps their power, plays with the wolves.
  infected,

  /// Charmed by the Joueur de Flûte.
  charmed,

  /// Voted out by the village but pardoned (the Village Idiot): he no longer votes.
  pardoned,
}

const _unset = Object();

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

  /// The side the player plays for now when it is not their role's own (an infected villager, a
  /// Wild Child whose model died, a Wolf-Hound who chose...). Null: the role's team applies.
  final Team? teamOverride;

  /// What the player is subject to besides their role.
  final Set<PlayerStatus> statuses;

  const Player({
    required this.id,
    required this.name,
    required this.roleId,
    this.alive = true,
    this.causeOfDeath,
    this.diedOnNight,
    this.diedOnPhase,
    this.teamOverride,
    this.statuses = const {},
  });

  /// [teamOverride] takes `null` to put the player back on their role's own side.
  Player copyWith({
    String? roleId,
    bool? alive,
    DeathCause? causeOfDeath,
    int? diedOnNight,
    GamePhase? diedOnPhase,
    Object? teamOverride = _unset,
    Set<PlayerStatus>? statuses,
  }) => Player(
    id: id,
    name: name,
    roleId: roleId ?? this.roleId,
    alive: alive ?? this.alive,
    causeOfDeath: causeOfDeath ?? this.causeOfDeath,
    diedOnNight: diedOnNight ?? this.diedOnNight,
    diedOnPhase: diedOnPhase ?? this.diedOnPhase,
    teamOverride: identical(teamOverride, _unset) ? this.teamOverride : teamOverride as Team?,
    statuses: statuses ?? this.statuses,
  );

  bool hasStatus(PlayerStatus status) => statuses.contains(status);

  @override
  String toString() => 'Player($id, roleId: $roleId, alive: $alive)';
}

class PlayerNotFoundException implements Exception {
  final String playerId;
  PlayerNotFoundException(this.playerId);

  @override
  String toString() => 'PlayerNotFoundException: no player with id "$playerId"';
}
