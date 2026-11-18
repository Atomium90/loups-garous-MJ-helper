import 'package:rules_engine/rules_engine.dart';

import '../../l10n/localizations.dart';

/// "Voyante", "2 Loups-Garous", "2 Villageois" (or "Seer", "2 Werewolves" in English).
String roleCountLabel(AppLocalizations l10n, String roleId, int count) =>
    count <= 1 ? l10n.roleName(roleId) : '$count ${l10n.rolePlural(roleId)}';

/// The "Dans la pioche" line before night 1 (and the recap sheet later):
/// "2 Loups-Garous · Voyante · Sorcière · Cupidon · Chasseur · 2 Villageois".
/// Loups-Garous first, plain Villageois last, everything else in the registry's
/// declared order in between.
String deckLine(AppLocalizations l10n, Map<String, int> composition, RoleRegistry registry) {
  final entries = composition.entries.where((e) => e.value > 0).toList();

  int rank(String roleId) {
    if (registry.byIdOrNull(roleId)?.team == Team.werewolves) return 0;
    if (roleId == 'villageois') return 2;
    return 1;
  }

  entries.sort((a, b) {
    final byRank = rank(a.key).compareTo(rank(b.key));
    if (byRank != 0) return byRank;
    return registry.roles
        .indexWhere((r) => r.id == a.key)
        .compareTo(registry.roles.indexWhere((r) => r.id == b.key));
  });

  return entries.map((e) => roleCountLabel(l10n, e.key, e.value)).join(' · ');
}

/// The Voleur's two reserve cards, spelled out with articles so the MJ sets
/// the matching physical cards aside: "le Chasseur · la Voyante".
String reserveLine(AppLocalizations l10n, List<String> reserveRoleIds) =>
    reserveRoleIds.map(l10n.roleWithArticle).join(' · ');
