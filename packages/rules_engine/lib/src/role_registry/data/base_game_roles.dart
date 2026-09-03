import '../../models/action_type.dart';
import '../../models/death_effect.dart';
import '../../models/order_constraint.dart';
import '../../models/role.dart';
import '../../models/team.dart';
import '../../models/wake_condition.dart';

/// The 8 dealt roles of the base "Les Loups-Garous de Thiercelieux" box, in
/// their official night-call order. Capitaine is deliberately not here: it's
/// an elected status any player can hold on top of their real role (see
/// GameState.captainPlayerId), not a role card dealt at setup.
const baseGameRoles = <Role>[
  Role(
    id: 'voleur',
    name: 'Voleur',
    team: null, // unresolved until he steals a card
    copies: 1,
    hasNightCall: true,
    wakeCondition: WakeCondition.firstNightOnly,
    actionType: ActionType.selectOne,
    ruleText:
        'Réveillez le Voleur. Il peut échanger sa carte avec l\'une des '
        'deux cartes non distribuées, ou garder la sienne.',
  ),
  Role(
    id: 'cupidon',
    name: 'Cupidon',
    team: Team.village,
    copies: 1,
    hasNightCall: true,
    wakeCondition: WakeCondition.firstNightOnly,
    orderConstraints: [OrderConstraint.after('voleur')],
    actionType: ActionType.selectTwo,
    ruleText:
        'Réveillez Cupidon. Il désigne deux joueurs qui tombent amoureux, '
        'puis les deux amoureux ouvrent les yeux pour se reconnaître avant '
        'de se rendormir.',
    mjTips: 'Notez qui sont les amoureux : si l\'un meurt, l\'autre meurt aussi.',
  ),
  Role(
    id: 'voyante',
    name: 'Voyante',
    team: Team.village,
    copies: 1,
    hasNightCall: true,
    wakeCondition: WakeCondition.everyNight,
    orderConstraints: [OrderConstraint.after('cupidon')],
    actionType: ActionType.selectOne,
    ruleText: 'Réveillez la Voyante. Elle désigne un joueur dont vous lui révélez le rôle.',
  ),
  Role(
    id: 'loup_garou',
    name: 'Loup-Garou',
    team: Team.werewolves,
    copies: 4,
    hasNightCall: true,
    wakeCondition: WakeCondition.everyNight,
    orderConstraints: [OrderConstraint.after('voyante')],
    actionType: ActionType.selectOne,
    ruleText: 'Réveillez les Loups-Garous. Ils désignent ensemble leur victime.',
  ),
  Role(
    id: 'sorciere',
    name: 'Sorcière',
    team: Team.village,
    copies: 1,
    hasNightCall: true,
    wakeCondition: WakeCondition.everyNight,
    orderConstraints: [OrderConstraint.after('loup_garou')],
    actionType: ActionType.binaryChoice,
    ruleText:
        'Réveillez la Sorcière. Montrez-lui la victime des Loups. Elle peut '
        'utiliser sa potion de vie et/ou sa potion de mort.',
    mjTips: 'Chaque potion ne peut être utilisée qu\'une seule fois par partie.',
  ),
  Role(
    id: 'villageois',
    name: 'Villageois',
    team: Team.village,
    copies: 13,
    hasNightCall: false,
    ruleText: 'Aucune action de nuit.',
  ),
  Role(
    id: 'petite_fille',
    name: 'Petite Fille',
    team: Team.village,
    copies: 1,
    hasNightCall: false,
    ruleText:
        'Aucun appel : elle peut risquer un œil pendant l\'appel des '
        'Loups-Garous, à ses risques.',
  ),
  Role(
    id: 'chasseur',
    name: 'Chasseur',
    team: Team.village,
    copies: 1,
    hasNightCall: false,
    onDeath: DeathEffect.hunterShot,
    ruleText:
        'Aucune action de nuit : à sa mort (jour ou nuit), il élimine '
        'immédiatement un joueur de son choix.',
  ),
];
