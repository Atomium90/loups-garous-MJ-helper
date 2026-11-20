import '../../models/action_type.dart';
import '../../models/death_effect.dart';
import '../../models/order_constraint.dart';
import '../../models/role.dart';
import '../../models/team.dart';
import '../../models/wake_condition.dart';

/// Every role the app implements, in the official night-call order (the Pacte booklet's, p.24),
/// which is also the order of the registry: a role is added here as it is implemented, at its
/// place in the call order. Only rules data: the names and the rule texts are the app's, in
/// each language it speaks. Capitaine is deliberately not here: it's an elected status any
/// player can hold on top of their real role (see GameState.captainPlayerId), not a role card
/// dealt at setup.
const allRoles = <Role>[
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
  // The Fox looks at three neighbours; the call is optional, and ends for good once he is wrong.
  // His place (after the Voyante) is the Pacte's; the settings can move him after the Sorcière.
  Role(
    id: 'renard',
    team: Team.village,
    suggestionTier: 3,
    hasNightCall: true,
    wakeCondition: WakeCondition.conditional,
    wakeGuard: WakeGuard.powerUnspent,
    optionalCall: true,
    orderConstraints: [OrderConstraint.after('voyante')],
    actionType: ActionType.selectOne,
  ),
  // A group of two: they wake together to know each other, on the first night and then every
  // other night if the MJ wants.
  Role(
    id: 'deux_soeurs',
    team: Team.village,
    groupSize: 2,
    hasNightCall: true,
    wakeCondition: WakeCondition.everyOtherNight,
    optionalCall: true,
  ),
  // He only identifies himself on the first night; his power plays in the morning.
  Role(
    id: 'montreur_d_ours',
    team: Team.village,
    suggestionTier: 3,
    hasNightCall: true,
    wakeCondition: WakeCondition.firstNightOnly,
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
