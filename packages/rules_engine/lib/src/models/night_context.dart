import 'role.dart';

/// What tonight's script depends on besides the roles themselves: which night it is, and the
/// few facts of the game that decide whether a role is called. The caller derives it from the
/// game state; the night script builder only reads it.
class NightContext {
  const NightContext({
    required this.nightIndex,
    this.firstNightOf = const {},
    this.spentPowers = const {},
    this.wolfSideLost = false,
    this.villagersPowerless = false,
  });

  /// 1-based.
  final int nightIndex;

  /// Role id -> the night its current holder began to be woken, when that is not the role's
  /// own [Role.firstWakeNight] (the Servante Devouee takes a role over mid-game: it is called
  /// "on night 1" of hers).
  final Map<String, int> firstNightOf;

  /// Roles whose one-time power has been used.
  final Set<String> spentPowers;

  /// A player of the wolf side has been eliminated.
  final bool wolfSideLost;

  /// The villagers have lost their powers (the Ancien died).
  final bool villagersPowerless;

  /// The night [role] is first woken, for its current holder.
  int firstNightFor(Role role) => firstNightOf[role.id] ?? role.firstWakeNight;
}
