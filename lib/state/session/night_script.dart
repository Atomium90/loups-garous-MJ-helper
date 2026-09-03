import 'package:rules_engine/rules_engine.dart';

const _builder = NightScriptBuilder();

/// The role id an un-identified player carries in the engine until the MJ
/// records who really holds a card. Only ever `villageois` (which has no night
/// call), so "a player whose roleId isn't this" is exactly "a confirmed
/// holder".
const kPlaceholderRoleId = 'villageois';

/// Tonight's ordered wake list.
///
/// Built from the composition **and** from the roles players actually hold
/// right now. Pre-deal the two are the same. After the Voleur swaps his card
/// for one of the reserve cards, that stolen role may not be in the
/// composition at all (the MJ set it aside) - deriving from the live player
/// roles is what lets the script still call, say, a stolen Voyante.
NightScript buildNightScript({
  required GameState engine,
  required Map<String, int> composition,
  RoleRegistry registry = RoleRegistry.base,
}) {
  final nightIndex = engine.nightIndex;

  // Confirmed holders' roles: everyone the deal / a reveal / a Voleur swap has
  // pinned down. The placeholder is filtered out (it never wakes anyway).
  final heldRoleIds = <String>{
    for (final p in engine.players)
      if (p.roleId != kPlaceholderRoleId) p.roleId,
  };

  if (nightIndex <= 1) {
    // Night 1 is built before the blind deal is known, so `heldRoleIds` is
    // normally empty and this is just the composition. Once the Voleur has
    // swapped mid-night, the stolen role joins in and `NightScriptBuilder`
    // slots it into the call order (the cursor already sits past the Voleur).
    final ids = <String>{
      for (final entry in composition.entries)
        if (entry.value > 0) entry.key,
      ...heldRoleIds,
    };
    final roles = [for (final id in ids) registry.byId(id)];
    return _builder.build(
      compositionRoles: roles,
      aliveRoleIds: {
        for (final r in roles)
          if (r.hasNightCall) r.id,
      },
      nightIndex: nightIndex,
    );
  }

  // Night 2+: a night-calling role stays in the script while a holder might
  // still be alive - a living player already holds it, or the composition
  // calls for more copies than have been confirmed (an un-identified holder
  // could be alive).
  final callable = <Role>[];
  final seen = <String>{};
  void consider(Role role) {
    if (!role.hasNightCall || !seen.add(role.id)) return;
    final known = engine.players.where((p) => p.roleId == role.id).toList();
    final anyAlive = known.any((p) => p.alive);
    final expected = composition[role.id] ?? 0;
    if (anyAlive || known.length < expected) callable.add(role);
  }

  for (final entry in composition.entries) {
    if (entry.value > 0) consider(registry.byId(entry.key));
  }
  for (final id in heldRoleIds) {
    consider(registry.byId(id));
  }

  return _builder.build(
    compositionRoles: callable,
    aliveRoleIds: {for (final r in callable) r.id},
    nightIndex: nightIndex,
  );
}
