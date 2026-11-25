import 'dart:math';

import 'package:rules_engine/rules_engine.dart';

const _builder = NightScriptBuilder();

/// The call that wakes the players the Piper charmed so they recognise each other. Not a role
/// anyone holds - no card, no composition - so it lives here and not in the registry.
const kCharmedStepRole = Role(
  id: 'joueurs_charmes',
  team: Team.village,
  hasNightCall: true,
  wakeCondition: WakeCondition.everyNight,
);

/// [script] with the charmed players' call right after the Piper's, when a living player has been
/// charmed. Built from the game as it is now: the night the Piper charms for the first time, the
/// script grows this step once he has acted, and the cursor already sits on it.
NightScript _withCharmedStep(NightScript script, GameState engine) {
  final piperAt = script.steps.indexWhere((s) => s.role.id == 'joueur_de_flute');
  if (piperAt < 0) return script;
  final anyCharmed = engine.alivePlayers.any((p) => p.hasStatus(PlayerStatus.charmed));
  if (!anyCharmed) return script;
  final roles = [for (final s in script.steps) s.role]..insert(piperAt + 1, kCharmedStepRole);
  return NightScript(
    nightIndex: script.nightIndex,
    steps: [
      for (final (i, role) in roles.indexed)
        NightScriptStep(
          role: role,
          stepIndex: i + 1,
          identifyOnly: script.steps
              .where((s) => s.role.id == role.id)
              .any((s) => s.identifyOnly),
        ),
    ],
  );
}

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
///
/// [dealtComposition] is how many holders each role really has, when that differs from
/// [composition]: with a drawn Voleur reserve some cards of the composition sit in the middle.
/// It only decides, from night 2, which roles still have a holder to wake; night 1 keeps calling
/// every role of the composition (the MJ bluffs for a card that is in the reserve).
NightScript buildNightScript({
  required GameState engine,
  required Map<String, int> composition,
  Map<String, int>? dealtComposition,
  bool foxAfterWitch = false,
  bool whiteWolfOddNights = false,
  RoleRegistry registry = RoleRegistry.all,
}) {
  // Before night 1 (the Angel's vote) the script is night 1's.
  final nightIndex = max(1, engine.nightIndex);

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
      // The card the Actor took for tonight is a role of its own to call, with no holder.
      ?engine.actor?.current,
    };
    final roles = _inCallOrder(
      [for (final id in ids) registry.byId(id)],
      registry,
      foxAfterWitch: foxAfterWitch,
    );
    return _withCharmedStep(
      _builder.build(
        compositionRoles: roles,
        aliveRoleIds: {
          for (final r in roles)
            if (r.hasNightCall) r.id,
        },
        nightIndex: nightIndex,
        context: _contextFor(engine, nightIndex, whiteWolfOddNights: whiteWolfOddNights),
      ),
      engine,
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
    // A Piper infected by the Cursed Wolf-Father is a plain wolf: he is no longer called.
    final aliveKnown = known
        .where(
          (p) => p.alive && !(role.id == 'joueur_de_flute' && p.teamOverride == Team.werewolves),
        )
        .length;
    final expected = (dealtComposition ?? composition)[role.id] ?? 0;
    // A group (the Two Sisters) only has someone to wake while all of it is alive: one sister
    // left alone has nobody to recognise.
    final holderLeft = aliveKnown >= role.groupSize;
    if (holderLeft || known.length < expected) callable.add(role);
  }

  for (final entry in composition.entries) {
    if (entry.value > 0) consider(registry.byId(entry.key));
  }
  for (final id in heldRoleIds) {
    consider(registry.byId(id));
  }
  final actorCard = engine.actor?.current;
  if (actorCard != null && seen.add(actorCard)) callable.add(registry.byId(actorCard));

  final inOrder = _inCallOrder(callable, registry, foxAfterWitch: foxAfterWitch);
  return _withCharmedStep(
    _builder.build(
      compositionRoles: inOrder,
      aliveRoleIds: {for (final r in inOrder) r.id},
      nightIndex: nightIndex,
      context: _contextFor(engine, nightIndex, whiteWolfOddNights: whiteWolfOddNights),
    ),
    engine,
  );
}

/// What the game says about tonight's calls beyond the roles themselves.
///
/// With [whiteWolfOddNights] the White Werewolf's solo power starts on night 1: the odd nights.
NightContext _contextFor(
  GameState engine,
  int nightIndex, {
  required bool whiteWolfOddNights,
}) {
  // A role the Servante took over starts again for her the night after, as on a first night. (The
  // Cupidon cannot pair a second couple: his call is not offered.)
  final firstNightOf = <String, int>{if (whiteWolfOddNights) 'loup_garou_blanc': 1};
  final takeover = engine.servantTakeover;
  if (takeover != null && takeover.roleId != 'cupidon') {
    firstNightOf[takeover.roleId] = takeover.day + 1;
  }
  return NightContext(
  nightIndex: nightIndex,
  firstNightOf: firstNightOf,
  spentPowers: engine.spentPowersBeforeTonight,
  wolfSideLost: engine.wolfSideLost(RoleRegistry.all),
  villagersPowerless: engine.villagersPowerless,
  actorCard: engine.actor?.current,
  );
}

/// [roles] in the registry's declaration order, which is the official wake order.
///
/// The builder keeps the order it is given for roles that no constraint relates, and a role's
/// constraints only name its neighbours in the chain (Loups come after the Voyante, which comes
/// after Cupidon). With the Voyante absent nothing ties the Loups to Cupidon any more, so the
/// order the caller lists them in decides: the composition's own key order must not.
///
/// With [foxAfterWitch] the Fox is called right after the Sorcière (the Best Of booklet's order)
/// instead of after the Voyante (the Pacte's, the registry's).
List<Role> _inCallOrder(List<Role> roles, RoleRegistry registry, {bool foxAfterWitch = false}) {
  final position = {for (final (i, r) in registry.roles.indexed) r.id: i};
  final ordered = [...roles]..sort((a, b) => position[a.id]!.compareTo(position[b.id]!));
  if (!foxAfterWitch) return ordered;
  final fox = ordered.where((r) => r.id == 'renard').firstOrNull;
  final witch = ordered.indexWhere((r) => r.id == 'sorciere');
  if (fox == null || witch < 0) return ordered;
  ordered.remove(fox);
  ordered.insert(ordered.indexWhere((r) => r.id == 'sorciere') + 1, fox);
  return ordered;
}

/// The roles the Comédien's cards can be: those he can play of which the owned boxes still hold a
/// card. The cards are taken out of the box, not out of the deal, so a role the composition (or
/// the Voleur's reserve) already uses is not one of them - two Sorcières would be in play.
List<String> actorCardOptions({
  required Map<String, int> composition,
  required List<String> reserveRoleIds,
  required bool reserveDrawn,
  required CardPool pool,
}) {
  final used = {...composition};
  if (reserveDrawn) {
    used.update(kPlaceholderRoleId, (n) => n + 2, ifAbsent: () => 2);
  } else {
    for (final id in reserveRoleIds) {
      used.update(id, (n) => n + 1, ifAbsent: () => 1);
    }
  }
  return [
    for (final id in actorCardRoleIds)
      if (pool.cardsLeft(id, used) > 0) id,
  ];
}

/// The cards of the deal's pack, in registry order: the composition, plus the two Simples
/// Villageois a drawn Voleur reserve adds to it.
List<({String roleId, int count})> dealPackOf(
  Map<String, int> composition, {
  required bool reserveDrawn,
}) {
  final counts = {...composition};
  if (reserveDrawn) counts.update(kPlaceholderRoleId, (n) => n + 2, ifAbsent: () => 2);
  return [
    for (final role in RoleRegistry.all.roles)
      if ((counts[role.id] ?? 0) > 0) (roleId: role.id, count: counts[role.id]!),
  ];
}

/// The cards of [pack] the MJ has not put on a player yet, given the [noted] role of every roster
/// seat (null while not noted), in the pack's order. The seat being edited is left out of
/// [noted] by the caller, so its own card is offered again.
List<({String roleId, int left})> cardsLeftIn(
  List<({String roleId, int count})> pack,
  Iterable<String?> noted,
) {
  final used = <String, int>{};
  for (final id in noted) {
    if (id != null) used.update(id, (n) => n + 1, ifAbsent: () => 1);
  }
  return [
    for (final card in pack)
      if (card.count - (used[card.roleId] ?? 0) > 0)
        (roleId: card.roleId, left: card.count - (used[card.roleId] ?? 0)),
  ];
}

/// The composition less the cards a drawn Voleur reserve left in the middle, plus the two
/// Simples Villageois it added to the pack. [composition] itself when the reserve is not drawn
/// or not noted yet.
Map<String, int> dealtCompositionOf(
  Map<String, int> composition,
  List<String> reserveRoleIds, {
  required bool reserveDrawn,
}) {
  if (!reserveDrawn || reserveRoleIds.isEmpty) return composition;
  final counts = {...composition};
  counts.update(kPlaceholderRoleId, (n) => n + 2, ifAbsent: () => 2);
  for (final id in reserveRoleIds) {
    counts.update(id, (n) => n - 1, ifAbsent: () => -1);
  }
  return {
    for (final entry in counts.entries)
      if (entry.value > 0) entry.key: entry.value,
  };
}
