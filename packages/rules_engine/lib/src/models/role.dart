import 'action_type.dart';
import 'death_effect.dart';
import 'order_constraint.dart';
import 'team.dart';
import 'wake_condition.dart';

class Role {
  /// Stable key, never shown: the app looks the role's name and texts up by it.
  final String id;

  /// The side the role starts on. [Team.ambiguous] for the roles whose side is only settled
  /// during the game (the Voleur until he steals a card).
  final Team team;

  /// Null for base game roles.
  final String? extensionId;

  /// Whether several players can hold this role in one game (the Loups-Garous, the Simples
  /// Villageois, the Villageois-Villageois). Every other role is limited to one holder, even
  /// when several owned boxes each ship a card of it.
  final bool multiple;

  /// How many players the role takes at once, all or none: the Deux Sœurs are 2, the Trois
  /// Frères 3. The composition counts these slots, and never splits a group.
  final int groupSize;

  /// Palier de suggestion pour CompositionAdvisor : les rôles d'un même palier sont
  /// interchangeables (tirage aléatoire s'ils sont plus nombreux que les places restantes).
  /// Palier 1 = le plus "essentiel", inclus en premier. Null = jamais suggéré automatiquement
  /// (le MJ l'ajoute lui-même) - le cas du Voleur (exige de choisir 2 cartes de réserve) et des
  /// rôles à exemplaires multiples (loup_garou, villageois), gérés séparément par l'advisor.
  final int? suggestionTier;

  /// Whether this role is ever emitted as a night-script step by
  /// NightScriptBuilder. False for roles that are passive, day-phase only,
  /// or purely event-triggered (e.g. on death).
  final bool hasNightCall;

  /// Null iff [hasNightCall] is false.
  final WakeCondition? wakeCondition;

  /// The first night the role is woken (1 unless its power only starts later: the White Werewolf
  /// from night 2). Ignored when [hasNightCall] is false.
  final int firstWakeNight;

  /// What a [WakeCondition.conditional] role waits on; [WakeGuard.none] for the others.
  final WakeGuard wakeGuard;

  /// The role is also called on the first night, just to be identified, even when its power only
  /// starts later (the White Werewolf wakes with the wolves that night, and alone from the second).
  final bool knownOnFirstNight;

  /// The call may be skipped by the MJ without any consequence: the role has no obligation to
  /// act (the Fox, the Sisters, the Brothers). The script offers it as a step to pass.
  final bool optionalCall;

  /// Settled before the village goes to sleep, not at a night call: the MJ notes a card shown at
  /// the deal, or a division of the village. Nobody wakes. Such a role comes first in the first
  /// night's script, and the narration of the night starts after it.
  final bool preparation;

  /// The app plays this role wrongly, or only by asking the MJ at the last moment, unless it knows
  /// who holds it from the deal: its power hangs on the neighbours (the Fox, the Bear Tamer), on a
  /// vote before the first night (the Angel), or the role has no call to be recognised by (the
  /// Elder, the Knight, the Village Idiot, the Scapegoat, the Devoted Servant).
  final bool needsDealNotes;
  final List<OrderConstraint> orderConstraints;
  final ActionType actionType;

  /// Effect resolved by the death cascade when a player with this role dies.
  final DeathEffect onDeath;

  const Role({
    required this.id,
    required this.team,
    this.extensionId,
    this.multiple = false,
    this.groupSize = 1,
    this.suggestionTier,
    required this.hasNightCall,
    this.wakeCondition,
    this.firstWakeNight = 1,
    this.wakeGuard = WakeGuard.none,
    this.optionalCall = false,
    this.knownOnFirstNight = false,
    this.preparation = false,
    this.needsDealNotes = false,
    this.orderConstraints = const [],
    this.actionType = ActionType.none,
    this.onDeath = DeathEffect.none,
  });

  @override
  bool operator ==(Object other) => other is Role && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Role($id)';
}
