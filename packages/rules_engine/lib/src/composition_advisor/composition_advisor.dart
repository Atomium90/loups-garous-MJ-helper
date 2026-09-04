import 'dart:math';

import '../models/role.dart';
import '../role_registry/role_registry.dart';
import 'composition_suggestion.dart';

/// Suggests a composition for a player count, from role metadata alone
/// ([Role.copies], [Role.suggestionTier]) - no per-player-count table to hand-maintain, so a
/// new extension role only needs its own metadata to start showing up in suggestions.
class CompositionAdvisor {
  CompositionAdvisor(this.registry, {Random? random}) : _random = random ?? Random();

  final RoleRegistry registry;

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
    final wolves = _wolfTarget(playerCount);

    final pool = registry.roles.where((r) => r.suggestionTier != null).toList()
      ..sort((a, b) => a.suggestionTier!.compareTo(b.suggestionTier!));
    final specialsTarget = min(
      pool.length,
      max(0, min(4 + (playerCount - 8) ~/ 4, playerCount - wolves)),
    );
    final chosen = _fillByTier(pool, specialsTarget);

    final counts = <String, int>{};
    if (wolves > 0) counts['loup_garou'] = wolves;
    for (final role in chosen) {
      counts[role.id] = 1;
    }
    final villagers = playerCount - wolves - chosen.length;
    if (villagers > 0) counts['villageois'] = villagers;
    return CompositionSuggestion(counts);
  }

  int _wolfTarget(int playerCount) {
    final cap = registry.byIdOrNull('loup_garou')?.copies ?? 0;
    for (final band in _wolfBands) {
      if (playerCount >= band.minPlayers) return min(band.wolves, min(cap, playerCount));
    }
    return min(cap, playerCount);
  }

  /// Consumes [pool] (already sorted by tier) tier by tier until [target] roles are picked.
  /// A tier that would overflow the remaining room is shuffled first, so which of its
  /// interchangeable roles get cut varies across calls - the whole point of tiers over a
  /// strict priority order (see `CompositionEditor.rerollSuggestion`).
  List<Role> _fillByTier(List<Role> pool, int target) {
    final chosen = <Role>[];
    var i = 0;
    while (i < pool.length && chosen.length < target) {
      var j = i + 1;
      while (j < pool.length && pool[j].suggestionTier == pool[i].suggestionTier) {
        j++;
      }
      final sameTier = pool.sublist(i, j);
      final room = target - chosen.length;
      chosen.addAll(sameTier.length <= room ? sameTier : (sameTier..shuffle(_random)).take(room));
      i = j;
    }
    return chosen;
  }
}
