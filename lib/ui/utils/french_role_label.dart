import 'package:rules_engine/rules_engine.dart';

/// French-plural role names never pluralise the same way ("Loup-Garou" ->
/// "Loups-Garous", "Villageois" invariable), and `Role.name` only stores the
/// singular. Only these two base-box roles ever appear with a count > 1, so a
/// 2-entry table + an "append s" fallback covers V1. Once extensions add more
/// scalable roles, a real `namePlural` field on `rules_engine`'s `Role` is the
/// right home for this.
const _irregularPlurals = {
  'loup_garou': 'Loups-Garous',
  'villageois': 'Villageois',
};

/// "Voyante", "2 Loups-Garous", "2 Villageois".
String frenchRoleLabel(String roleId, int count, RoleRegistry registry) {
  final role = registry.byId(roleId);
  if (count <= 1) return role.name;
  return '$count ${frenchRolePlural(roleId, registry)}';
}

/// The bare plural: "Loups-Garous", "Voyantes", "Villageois".
String frenchRolePlural(String roleId, RoleRegistry registry) =>
    _irregularPlurals[roleId] ?? '${registry.byId(roleId).name}s';

const _feminineRoles = {'voyante', 'sorciere', 'petite_fille'};

/// "le Chasseur", "la Voyante" - for reveal / chain copy ("Noa était le Chasseur").
String roleWithArticle(String roleId, RoleRegistry registry) =>
    '${_feminineRoles.contains(roleId) ? 'la' : 'le'} ${registry.byId(roleId).name}';

/// The "Dans la pioche" line on A2 (and the recap sheet later):
/// "2 Loups-Garous · Voyante · Sorcière · Cupidon · Chasseur · 2 Villageois".
/// Loups-Garous first, plain Villageois last, everything else in the registry's
/// declared order in between.
String frenchDeckLine(Map<String, int> composition, RoleRegistry registry) {
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

  return entries.map((e) => frenchRoleLabel(e.key, e.value, registry)).join(' · ');
}
