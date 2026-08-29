import 'package:rules_engine/rules_engine.dart';

const _builder = NightScriptBuilder();

/// Tonight's ordered wake list. Night 1 is built from the composition (the
/// blind deal isn't known yet - `NightScriptBuilder` explicitly supports
/// this); later nights from the roles of players still alive.
NightScript buildNightScript({
  required GameState engine,
  required Map<String, int> composition,
  RoleRegistry registry = RoleRegistry.base,
}) {
  if (engine.nightIndex <= 1) {
    final roles = [
      for (final entry in composition.entries)
        if (entry.value > 0) registry.byId(entry.key),
    ];
    final nightCallers = {
      for (final r in roles)
        if (r.hasNightCall) r.id,
    };
    return _builder.build(
      compositionRoles: roles,
      aliveRoleIds: nightCallers,
      nightIndex: engine.nightIndex,
    );
  }

  final aliveRoleIds = engine.alivePlayers.map((p) => p.roleId).toSet();
  return _builder.build(
    compositionRoles: [for (final id in aliveRoleIds) registry.byId(id)],
    aliveRoleIds: aliveRoleIds,
    nightIndex: engine.nightIndex,
  );
}
