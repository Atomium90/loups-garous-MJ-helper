class Player {
  final String id;
  final String name;

  /// Mutable via Voleur's swap.
  final String roleId;
  final bool alive;

  const Player({
    required this.id,
    required this.name,
    required this.roleId,
    this.alive = true,
  });

  Player copyWith({String? roleId, bool? alive}) => Player(
    id: id,
    name: name,
    roleId: roleId ?? this.roleId,
    alive: alive ?? this.alive,
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
