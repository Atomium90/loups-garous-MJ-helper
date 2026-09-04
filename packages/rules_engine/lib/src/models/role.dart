import 'action_type.dart';
import 'death_effect.dart';
import 'order_constraint.dart';
import 'team.dart';
import 'wake_condition.dart';

class Role {
  final String id;
  final String name;

  /// Null only for Voleur: his team is unresolved until he steals a card.
  final Team? team;

  /// Null for base game roles.
  final String? extensionId;

  /// How many physical cards of this role its box ships with - the ceiling on
  /// how many can be in play plus set aside (the Voleur's reserve). Defaults
  /// to 1 for the singleton roles; the box data overrides it for the ones
  /// that ship in multiples (4 Loups-Garous, 13 Villageois in the base box).
  final int copies;

  /// Palier de suggestion pour CompositionAdvisor : les rôles d'un même palier sont
  /// interchangeables (tirage aléatoire s'ils sont plus nombreux que les places restantes).
  /// Palier 1 = le plus "essentiel", inclus en premier. Null = jamais suggéré automatiquement
  /// (le MJ l'ajoute lui-même) - le cas du Voleur (exige de choisir 2 cartes de réserve) et des
  /// deux rôles à copies multiples (loup_garou, villageois), gérés séparément par l'advisor.
  final int? suggestionTier;

  /// Whether this role is ever emitted as a night-script step by
  /// NightScriptBuilder. False for roles that are passive, day-phase only,
  /// or purely event-triggered (e.g. on death).
  final bool hasNightCall;

  /// Null iff [hasNightCall] is false.
  final WakeCondition? wakeCondition;
  final List<OrderConstraint> orderConstraints;
  final ActionType actionType;

  /// Effect resolved by the death cascade when a player with this role dies.
  final DeathEffect onDeath;

  /// Short, action-focused instruction shown to the MJ. Not narrative rule
  /// text: the app is an assistant, not a replacement for the MJ knowing
  /// the game.
  final String ruleText;
  final String? mjTips;

  const Role({
    required this.id,
    required this.name,
    required this.team,
    this.extensionId,
    this.copies = 1,
    this.suggestionTier,
    required this.hasNightCall,
    this.wakeCondition,
    this.orderConstraints = const [],
    this.actionType = ActionType.none,
    this.onDeath = DeathEffect.none,
    required this.ruleText,
    this.mjTips,
  });

  @override
  bool operator ==(Object other) => other is Role && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Role($id)';
}
