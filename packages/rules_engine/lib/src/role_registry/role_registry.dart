import 'package:collection/collection.dart';

import '../models/role.dart';
import '../models/team.dart';
import 'data/base_game_roles.dart';

class RoleRegistry {
  const RoleRegistry(this.roles);

  final List<Role> roles;

  /// Every role the app implements, in night-call order (registry order is wake order). Resolves
  /// any role id a game can hold, whatever boxes are owned today: to offer only what a set of
  /// boxes can supply, ask a `CardPool` for its `available` view.
  static const RoleRegistry all = RoleRegistry(baseGameRoles);

  Role byId(String id) =>
      roles.firstWhereOrNull((r) => r.id == id) ?? (throw RoleNotFoundException(id));

  Role? byIdOrNull(String id) => roles.firstWhereOrNull((r) => r.id == id);

  List<Role> byTeam(Team team) =>
      roles.where((r) => r.team == team).toList(growable: false);
}

class RoleNotFoundException implements Exception {
  final String roleId;
  RoleNotFoundException(this.roleId);

  @override
  String toString() => 'RoleNotFoundException: no role with id "$roleId"';
}
