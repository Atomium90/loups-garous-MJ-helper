import 'night_context.dart';
import 'role.dart';
import 'team.dart';

/// When a role with a night call is woken, counted from the night it starts waking (its
/// [Role.firstWakeNight], or the night its current holder began, see [NightContext]).
enum WakeCondition {
  /// Every night from the first one.
  everyNight,

  /// Only on the first night.
  firstNightOnly,

  /// The first night, then every second one after it (1, 3, 5...).
  everyOtherNight,

  /// Every night, as long as the role's [Role.wakeGuard] holds.
  conditional,
}

/// What makes a [WakeCondition.conditional] role stop (or start) waking.
enum WakeGuard {
  /// No guard: only meaningful for roles that are not conditional.
  none,

  /// The role has a power it can use once, and has not used it yet (the Infect Pere des Loups).
  powerUnspent,

  /// No wolf-side player has died yet (the Grand-Mechant-Loup's second call).
  noWolfDeathYet,
}

extension WakeConditionActivation on WakeCondition {
  /// Whether [role] is woken tonight, given [context]. Roles of the village that lost their
  /// powers (the Ancien died) are filtered out by the caller, not here.
  bool isActiveFor(Role role, NightContext context) {
    final first = context.firstNightFor(role);
    final night = context.nightIndex;
    if (night < first) return false;
    switch (this) {
      case WakeCondition.everyNight:
        return true;
      case WakeCondition.firstNightOnly:
        return night == first;
      case WakeCondition.everyOtherNight:
        return (night - first).isEven;
      case WakeCondition.conditional:
        return switch (role.wakeGuard) {
          WakeGuard.powerUnspent => !context.spentPowers.contains(role.id),
          WakeGuard.noWolfDeathYet => !context.wolfSideLost,
          WakeGuard.none => throw StateError(
            'Role "${role.id}" is conditional but has no wakeGuard',
          ),
        };
    }
  }
}

/// Whether the powers of villagers are gone (the Ancien was killed by the village): a village
/// role with a night call then stays asleep.
bool losesNightCall(Role role, NightContext context) =>
    context.villagersPowerless && role.team == Team.village;
