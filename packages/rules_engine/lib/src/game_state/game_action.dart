/// A fact the MJ reports to the state machine. GameStateMachine never
/// invents an action itself, it only reacts to these.
sealed class GameAction {}

class VoleurSwap implements GameAction {
  final String voleurPlayerId;

  /// Null means he keeps his own card.
  final String? stolenRoleId;

  const VoleurSwap({required this.voleurPlayerId, this.stolenRoleId});
}

/// The Fox's sniff: he picked [middlePlayerId] (the middle of three neighbours) and the MJ
/// says whether a wolf is among the three. With none, his power is gone for good.
class FoxSniff implements GameAction {
  final String middlePlayerId;
  final bool wolfFound;

  const FoxSniff({required this.middlePlayerId, required this.wolfFound});
}

/// The Wild Child picks his role model (night 1).
class WildChildChooseModel implements GameAction {
  final String childPlayerId;
  final String modelPlayerId;

  const WildChildChooseModel({required this.childPlayerId, required this.modelPlayerId});
}

/// The Wolf-Hound's final choice: [wolf] true joins the wolves, false stays a villager.
class ChienLoupChoose implements GameAction {
  final String playerId;
  final bool wolf;

  const ChienLoupChoose({required this.playerId, required this.wolf});
}

/// The Cursed Wolf-Father infects the wolves' victim instead of letting it be eaten. Once per game.
class InfectVictim implements GameAction {
  const InfectVictim();
}

/// The Big Bad Wolf's second victim.
class BigBadWolfTarget implements GameAction {
  final String targetPlayerId;

  const BigBadWolfTarget({required this.targetPlayerId});
}

/// The White Werewolf eats one of the other wolves.
class WhiteWolfEat implements GameAction {
  final String targetPlayerId;

  const WhiteWolfEat({required this.targetPlayerId});
}

/// The Piper charms one or two players (night).
class PiperCharm implements GameAction {
  final List<String> playerIds;

  const PiperCharm({required this.playerIds});
}

/// Resolves a pending PendingKnightWound: the wolf the sword left diseased, or null when the MJ
/// finds none to wound. [atNightEnd] is the setting: the disease strikes at the end of the next
/// night instead of its beginning.
class KnightContaminate implements GameAction {
  final String? wolfPlayerId;
  final bool atNightEnd;

  const KnightContaminate({this.wolfPlayerId, this.atNightEnd = false});
}

/// The Defender protects a player from the wolves tonight (himself included, not the one he
/// protected last night).
class DefenderProtect implements GameAction {
  final String targetPlayerId;

  const DefenderProtect({required this.targetPlayerId});
}

/// The Wandering Judge gives his secret sign during the village vote: a second vote follows right
/// away. Once per game.
class JudgeSign implements GameAction {
  const JudgeSign();
}

/// The MJ divides the village in two groups for the Abominable Sectaire: [groupAPlayerIds] are the
/// first group, everyone else the second.
class DivideVillage implements GameAction {
  final Set<String> groupAPlayerIds;

  const DivideVillage({required this.groupAPlayerIds});
}

/// The Servante Devouee reveals herself right after a village vote and takes the role of the
/// eliminated player. Refused if she is one of the lovers, or already did.
class ServantTakesRole implements GameAction {
  final String servantPlayerId;
  final String deadPlayerId;

  const ServantTakesRole({required this.servantPlayerId, required this.deadPlayerId});
}

/// The MJ lays the Comedien's cards face up: [roleIds] are up to [actorCardCount] distinct roles
/// among [actorCardRoleIds] (fewer when the boxes hold no more that are not dealt).
class ActorSetCards implements GameAction {
  final List<String> roleIds;

  const ActorSetCards({required this.roleIds});
}

/// The Comedien uses the power of [roleId] tonight, a card still on the table.
class ActorChooseCard implements GameAction {
  final String roleId;

  const ActorChooseCard({required this.roleId});
}

class CupidonPair implements GameAction {
  final String playerAId;
  final String playerBId;

  const CupidonPair({required this.playerAId, required this.playerBId});
}

class WolvesTarget implements GameAction {
  final String targetPlayerId;

  const WolvesTarget({required this.targetPlayerId});
}

class WitchLifePotion implements GameAction {
  const WitchLifePotion();
}

class WitchDeathPotion implements GameAction {
  final String targetPlayerId;

  const WitchDeathPotion({required this.targetPlayerId});
}

/// Closes the Sorcière's window: finalizes the pending wolf/witch targets
/// as real deaths (with dedupe if they're the same player), resolves the
/// death cascade, and advances the phase to day.
class FinalizeNight implements GameAction {
  const FinalizeNight();
}

class DayVoteElimination implements GameAction {
  final String targetPlayerId;

  const DayVoteElimination({required this.targetPlayerId});
}

/// Records a role the app could not learn on its own - almost always a dead
/// player whose card was never identified. Writes the [roleId], and if that
/// player is dead re-runs their on-death effect (the death cascade already
/// resolved their captain status and lovers link with role-independent data,
/// but skipped the Chasseur's shot because the role wasn't known yet).
class RevealRole implements GameAction {
  final String playerId;
  final String roleId;

  const RevealRole({required this.playerId, required this.roleId});
}

class ElectCaptain implements GameAction {
  final String playerId;

  const ElectCaptain({required this.playerId});
}

class StartNextNight implements GameAction {
  const StartNextNight();
}

/// Resolves a pending PendingHunterShot decision. A null [targetPlayerId] means
/// the Chasseur chooses not to shoot ("Il ne tire pas").
class HunterShoot implements GameAction {
  final String? targetPlayerId;

  const HunterShoot({this.targetPlayerId});
}

/// The village vote is tied. With a living Scapegoat ([scapegoatPlayerId]) he is eliminated in
/// place of the tied players, even if he is not one of them; without, nobody is.
class DayVoteTie implements GameAction {
  final String? scapegoatPlayerId;

  const DayVoteTie({this.scapegoatPlayerId});
}

/// Resolves a pending PendingScapegoatVoters: [allowedPlayerIds] are the only ones who vote on the
/// next day (empty: nobody does, so there is no vote).
class ScapegoatChooseVoters implements GameAction {
  final Set<String> allowedPlayerIds;

  const ScapegoatChooseVoters({required this.allowedPlayerIds});
}

/// Resolves a pending PendingCaptainSuccession decision with nobody: the Village Idiot's honor is
/// lost with him, not passed on.
class CaptainNoSuccessor implements GameAction {
  const CaptainNoSuccessor();
}

/// Resolves a pending PendingCaptainSuccession decision.
class CaptainNameSuccessor implements GameAction {
  final String successorPlayerId;

  const CaptainNameSuccessor({required this.successorPlayerId});
}
