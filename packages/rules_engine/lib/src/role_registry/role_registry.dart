import 'package:collection/collection.dart';

import '../models/role.dart';
import '../models/team.dart';
import 'data/base_game_roles.dart';

class RoleRegistry {
  const RoleRegistry(this.roles);

  final List<Role> roles;

  static const RoleRegistry base = RoleRegistry(baseGameRoles);
  // Future extensions plug in here, e.g.:
  // static const withNouvelleLune = RoleRegistry([...baseGameRoles, ...nouvelleLuneRoles]);

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
