import 'dart:math';

import '../boxes/card_pool.dart';
import '../models/role.dart';
import '../role_registry/role_registry.dart';
import 'composition_suggestion.dart';

/// Suggests a composition for a player count, from role metadata alone
/// ([Role.suggestionTier] and what the owned boxes can supply) - no per-player-count table to
/// hand-maintain, so a new extension role only needs its own metadata to start showing up in
/// suggestions.
class CompositionAdvisor {
  CompositionAdvisor(this.pool, {Random? random}) : _random = random ?? Random();

  /// What the MJ owns: only roles it can supply are ever suggested.
  final CardPool pool;

  RoleRegistry get registry => pool.available;

  /// Breaks ties among same-tier roles beyond the essential tier(s). Injectable so callers
  /// (tests, a stable preview) can get a deterministic pick.
  final Random _random;

  /// Werewolf team size by player-count band - a starting point tuned to the base box, not a
  /// rule copied from the rulebook. Extensions that widen the player range, or add their own
  /// wolf-team roles, may need more bands here. Checked highest-first.
  static const _wolfBands = [
    (minPlayers: 15, wolves: 4),
    (minPlayers: 11, wolves: 3),
    (minPlayers: 8, wolves: 2),
  ];

  CompositionSuggestion suggest(int playerCount) {
    final wolfCap = min(pool.maxCopies('loup_garou'), playerCount);
    var wolves = min(_wolfTarget(playerCount), wolfCap);

    final candidates = registry.roles.where((r) => r.suggestionTier != null).toList()
      ..sort((a, b) => a.suggestionTier!.compareTo(b.suggestionTier!));
    final specialsTarget = min(
      candidates.length,
      max(0, min(4 + (playerCount - 8) ~/ 4, playerCount - wolves)),
    );

    var chosen = _fillByTier(candidates, specialsTarget);
    // A box can hold fewer Simples Villageois than the table needs (and a sticker role takes
    // one of them): add roles first, then wolves, until the rest fits. With no card left to
    // add, the counts come up short of [playerCount] - the player cap keeps that from
    // happening in practice.
    var deficit = _villagerDeficit(playerCount, wolves, chosen);
    while (deficit > 0 && chosen.length < candidates.length) {
      chosen = _fillByTier(candidates, min(candidates.length, chosen.length + deficit));
      deficit = _villagerDeficit(playerCount, wolves, chosen);
    }
    if (deficit > 0) {
      wolves += min(deficit, wolfCap - wolves);
    }

    final counts = <String, int>{};
    if (wolves > 0) counts['loup_garou'] = wolves;
    for (final role in chosen) {
      counts[role.id] = role.groupSize;
    }
    final villagers = playerCount - wolves - _slots(chosen);
    if (villagers > 0) counts['villageois'] = villagers;
    return CompositionSuggestion(counts);
  }

  int _slots(List<Role> roles) => roles.fold<int>(0, (sum, r) => sum + r.groupSize);

  /// How many Simples Villageois the table needs beyond what the owned boxes can supply, once
  /// [chosen] roles (sticker ones included) are in.
  int _villagerDeficit(int playerCount, int wolves, List<Role> chosen) {
    final stickers = {
      for (final role in chosen)
        if (pool.isStickerOnly(role.id)) role.id: 1,
    };
    final villagers = playerCount - wolves - _slots(chosen);
    return villagers - pool.cardsLeft('villageois', stickers);
  }

  int _wolfTarget(int playerCount) {
    for (final band in _wolfBands) {
      if (playerCount >= band.minPlayers) return band.wolves;
    }
    return 0;
  }

  /// Consumes [candidates] (already sorted by tier) tier by tier until [target] roles are picked.
  /// A tier that would overflow the remaining room is shuffled first, so which of its
  /// interchangeable roles get cut varies across calls - the whole point of tiers over a
  /// strict priority order (see `CompositionEditor.rerollSuggestion`).
  List<Role> _fillByTier(List<Role> candidates, int target) {
    final chosen = <Role>[];
    var i = 0;
    while (i < candidates.length && chosen.length < target) {
      var j = i + 1;
      while (j < candidates.length && candidates[j].suggestionTier == candidates[i].suggestionTier) {
        j++;
      }
      final sameTier = candidates.sublist(i, j);
      final room = target - chosen.length;
      chosen.addAll(sameTier.length <= room ? sameTier : (sameTier..shuffle(_random)).take(room));
      i = j;
    }
    return chosen;
  }
}
