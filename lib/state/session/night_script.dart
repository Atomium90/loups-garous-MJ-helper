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

  // Night 2+: from the composition, keeping a night-calling role unless every
  // one of its holders is known dead. An un-identified holder (fewer players
  // confirmed in the role than the composition calls for) might still be alive,
  // so the role stays in the script and its identify step re-appears. Only
  // `villageois` is ever the un-identified placeholder, and it has no night
  // call, so `players.where(roleId == id)` is the set of *confirmed* holders
  // for any night-calling role.
  final callable = <Role>[];
  for (final entry in composition.entries) {
    if (entry.value <= 0) continue;
    final role = registry.byId(entry.key);
    if (!role.hasNightCall) continue;
    final known = engine.players.where((p) => p.roleId == role.id).toList();
    final anyAlive = known.any((p) => p.alive);
    if (anyAlive || known.length < entry.value) {
      callable.add(role);
    }
  }
  return _builder.build(
    compositionRoles: callable,
    aliveRoleIds: {for (final r in callable) r.id},
    nightIndex: engine.nightIndex,
  );
}
