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
  // His card is public from the deal on: the MJ only notes who shows it, before the night.
  Role(
    id: 'villageois_villageois',
    team: Team.village,
    multiple: true,
    hasNightCall: true,
    wakeCondition: WakeCondition.firstNightOnly,
    preparation: true,
  ),
  // The village is split in two groups before the night; he wins alone once the group he is not
  // in is gone. The MJ notes who he is and how the village was divided.
  Role(
    id: 'abominable_sectaire',
    team: Team.solo,
    hasNightCall: true,
    wakeCondition: WakeCondition.firstNightOnly,
    preparation: true,
  ),
  Role(
    id: 'voleur',
    team: Team.ambiguous, // settled only once he steals a card
    hasNightCall: true,
    wakeCondition: WakeCondition.firstNightOnly,
    actionType: ActionType.selectOne,
  ),
  // Each night he uses the power of one of three cards laid face up for him, until the next night;
  // the card then leaves the game. Once all three are used he is no longer called.
  Role(
    id: 'comedien',
    team: Team.ambiguous,
    hasNightCall: true,
    wakeCondition: WakeCondition.conditional,
    wakeGuard: WakeGuard.powerUnspent,
    optionalCall: true,
    orderConstraints: [OrderConstraint.after('voleur')],
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
    needsDealNotes: true,
    hasNightCall: true,
    wakeCondition: WakeCondition.conditional,
    wakeGuard: WakeGuard.powerUnspent,
    optionalCall: true,
    orderConstraints: [OrderConstraint.after('voyante')],
    actionType: ActionType.selectOne,
  ),
  // He only shows the MJ his secret sign on the first night; the once-a-game second vote it calls
  // for plays during the day.
  Role(
    id: 'juge_begue',
    team: Team.village,
    suggestionTier: 3,
    hasNightCall: true,
    wakeCondition: WakeCondition.firstNightOnly,
  ),
  // A group of two: they wake together on the first night to know each other. They have no power,
  // so there is no reason to wake them again.
  Role(
    id: 'deux_soeurs',
    team: Team.village,
    groupSize: 2,
    hasNightCall: true,
    wakeCondition: WakeCondition.firstNightOnly,
    optionalCall: true,
  ),
  // A group of three, like the sisters: they wake together, once, to know each other.
  Role(
    id: 'trois_freres',
    team: Team.village,
    groupSize: 3,
    hasNightCall: true,
    wakeCondition: WakeCondition.firstNightOnly,
    optionalCall: true,
  ),
  // He picks a role model on the first night; if the model is eliminated he turns into a wolf.
  Role(
    id: 'enfant_sauvage',
    team: Team.ambiguous,
    hasNightCall: true,
    wakeCondition: WakeCondition.firstNightOnly,
    actionType: ActionType.selectOne,
  ),
  // He only identifies himself on the first night; his power plays in the morning.
  Role(
    id: 'montreur_d_ours',
    team: Team.village,
    suggestionTier: 3,
    needsDealNotes: true,
    hasNightCall: true,
    wakeCondition: WakeCondition.firstNightOnly,
  ),
  // He protects a player from the wolves each night, right before the wolf pack.
  Role(
    id: 'salvateur',
    team: Team.village,
    suggestionTier: 3,
    hasNightCall: true,
    wakeCondition: WakeCondition.everyNight,
    actionType: ActionType.selectOne,
  ),
  // No call of his own in the booklets: on the first night, just before the wolves, the MJ asks
  // him whether he is a villager or a wolf, for good.
  Role(
    id: 'chien_loup',
    team: Team.ambiguous,
    hasNightCall: true,
    wakeCondition: WakeCondition.firstNightOnly,
    actionType: ActionType.binaryChoice,
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
  // The wolves' pack also holds these three, who each have their own turn right after them
  // (the booklets' order: the White Werewolf, the Cursed Wolf-Father, the Big Bad Wolf).
  Role(
    id: 'loup_garou_blanc',
    team: Team.solo,
    hasNightCall: true,
    wakeCondition: WakeCondition.everyOtherNight,
    firstWakeNight: 2,
    knownOnFirstNight: true,
    optionalCall: true,
    orderConstraints: [OrderConstraint.after('loup_garou')],
    actionType: ActionType.selectOne,
  ),
  Role(
    id: 'infect_pere_des_loups',
    team: Team.werewolves,
    hasNightCall: true,
    wakeCondition: WakeCondition.conditional,
    wakeGuard: WakeGuard.powerUnspent,
    optionalCall: true,
    orderConstraints: [OrderConstraint.after('loup_garou')],
    actionType: ActionType.binaryChoice,
  ),
  Role(
    id: 'grand_mechant_loup',
    team: Team.werewolves,
    hasNightCall: true,
    wakeCondition: WakeCondition.conditional,
    wakeGuard: WakeGuard.noWolfDeathYet,
    optionalCall: true,
    orderConstraints: [OrderConstraint.after('loup_garou')],
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
  // He charms two players a night, after the Witch; the charmed then wake to meet. Solo: he wins
  // when everyone else alive is charmed.
  Role(
    id: 'joueur_de_flute',
    team: Team.solo,
    hasNightCall: true,
    wakeCondition: WakeCondition.everyNight,
    orderConstraints: [OrderConstraint.after('sorciere')],
    actionType: ActionType.selectTwo,
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
  // Two lives against the wolves; eliminated by the village, the poison or the Hunter's shot, he
  // costs the villagers their powers.
  Role(
    id: 'ancien',
    team: Team.village,
    suggestionTier: 3,
    needsDealNotes: true,
    hasNightCall: false,
  ),
  // Devoured by the wolves, he leaves the first wolf to his left diseased.
  Role(
    id: 'chevalier',
    team: Team.village,
    suggestionTier: 3,
    needsDealNotes: true,
    hasNightCall: false,
    onDeath: DeathEffect.knightDisease,
  ),
  // No call: the game starts with a debate and a vote before the first night (night 0 of the
  // engine). Eliminated at that vote or during night 1, he wins; alive on the second day, he is a
  // Simple Villageois (see GameStateSides.sideOf).
  Role(
    id: 'ange',
    team: Team.solo,
    needsDealNotes: true,
    hasNightCall: false,
  ),
  // Voted out, he is pardoned once and no longer votes; devoured or shot he dies, and the honor of
  // Capitaine, if he held it, is lost with him.
  Role(
    id: 'idiot_du_village',
    team: Team.village,
    suggestionTier: 3,
    needsDealNotes: true,
    hasNightCall: false,
  ),
  // A tie in the village vote falls on him instead; eliminated, he names who votes next.
  Role(
    id: 'bouc_emissaire',
    team: Team.village,
    suggestionTier: 3,
    needsDealNotes: true,
    hasNightCall: false,
    onDeath: DeathEffect.scapegoatVoters,
  ),
  // No call: right after a village vote, before the card is shown, she may reveal herself and take
  // the eliminated player's role (see ServantTakesRole). Her side is whatever the role she takes
  // says.
  Role(
    id: 'servante_devouee',
    team: Team.ambiguous,
    needsDealNotes: true,
    hasNightCall: false,
  ),
];
