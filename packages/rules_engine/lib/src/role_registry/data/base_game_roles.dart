import '../../models/action_type.dart';
import '../../models/death_effect.dart';
import '../../models/order_constraint.dart';
import '../../models/role.dart';
import '../../models/team.dart';
import '../../models/wake_condition.dart';

/// The 8 dealt roles of the base "Les Loups-Garous de Thiercelieux" box, in
/// their official night-call order. Only rules data: the names and the rule texts are the
/// app's, in each language it speaks. Capitaine is deliberately not here: it's
/// an elected status any player can hold on top of their real role (see
/// GameState.captainPlayerId), not a role card dealt at setup.
const baseGameRoles = <Role>[
  Role(
    id: 'voleur',
    team: Team.ambiguous, // settled only once he steals a card
    hasNightCall: true,
    wakeCondition: WakeCondition.firstNightOnly,
    actionType: ActionType.selectOne,
  ),
  Role(
    id: 'cupidon',
    team: Team.village,
    suggestionTier: 2,
    hasNightCall: true,
    wakeCondition: WakeCondition.firstNightOnly,
    orderConstraints: [OrderConstraint.after('voleur')],
    actionType: ActionType.selectTwo,
  ),
  Role(
    id: 'voyante',
    team: Team.village,
    suggestionTier: 1,
    hasNightCall: true,
    wakeCondition: WakeCondition.everyNight,
    orderConstraints: [OrderConstraint.after('cupidon')],
    actionType: ActionType.selectOne,
  ),
  Role(
    id: 'loup_garou',
    team: Team.werewolves,
    multiple: true,
    hasNightCall: true,
    wakeCondition: WakeCondition.everyNight,
    orderConstraints: [OrderConstraint.after('voyante')],
    actionType: ActionType.selectOne,
  ),
  Role(
    id: 'sorciere',
    team: Team.village,
    suggestionTier: 1,
    hasNightCall: true,
    wakeCondition: WakeCondition.everyNight,
    orderConstraints: [OrderConstraint.after('loup_garou')],
    actionType: ActionType.binaryChoice,
  ),
  Role(
    id: 'villageois',
    team: Team.village,
    multiple: true,
    hasNightCall: false,
  ),
  Role(
    id: 'petite_fille',
    team: Team.village,
    suggestionTier: 3,
    hasNightCall: false,
  ),
  Role(
    id: 'chasseur',
    team: Team.village,
    suggestionTier: 2,
    hasNightCall: false,
    onDeath: DeathEffect.hunterShot,
  ),
];
