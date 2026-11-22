import 'package:collection/collection.dart';

import '../models/team.dart';
import 'death_cause.dart';
import 'game_phase.dart';
import 'pending_decision.dart';
import 'player.dart';

export 'game_phase.dart';

class WitchState {
  final bool lifePotionUsed;
  final bool deathPotionUsed;

  const WitchState({this.lifePotionUsed = false, this.deathPotionUsed = false});

  WitchState copyWith({bool? lifePotionUsed, bool? deathPotionUsed}) => WitchState(
    lifePotionUsed: lifePotionUsed ?? this.lifePotionUsed,
    deathPotionUsed: deathPotionUsed ?? this.deathPotionUsed,
  );
}

/// The Wild Child and the player he picked as his role model. When the model is eliminated he
/// becomes a werewolf (see [GameState.killPlayer]).
class WildChildState {
  final String childId;
  final String modelId;

  const WildChildState({required this.childId, required this.modelId});
}

/// The wolf the dead Knight left diseased: it dies when [dueNight] starts, or ends if
/// [atNightEnd] (the booklets differ: the Best Of says the beginning, Characters the end).
class KnightWound {
  final String wolfId;
  final int dueNight;
  final bool atNightEnd;

  const KnightWound({required this.wolfId, required this.dueNight, this.atNightEnd = false});
}

/// The players the dead Scapegoat let vote on [day] (the day number is the night index of that
/// day, as [GameState.nightIndex] reads during it). Everyone else sits it out.
class VoteRestriction {
  final Set<String> allowed;
  final int day;

  const VoteRestriction({required this.allowed, required this.day});
}

/// How the village was divided in two groups at the deal, for the Abominable Sectaire: [groupA] is
/// the first group, every other player is in the second.
class VillageDivision {
  final Set<String> groupA;

  const VillageDivision({required this.groupA});

  /// 0 for the first group, 1 for the second.
  int groupOf(String playerId) => groupA.contains(playerId) ? 0 : 1;
}

/// The Servante Devouee took over a role: who she is, the role, and the day it happened (the night
/// index of that day). She can do it once.
class ServantTakeover {
  final String playerId;
  final String roleId;
  final int day;

  const ServantTakeover({required this.playerId, required this.roleId, required this.day});
}

/// The Comedien's three cards: those laid face up for him, the ones already used, and the one
/// whose power he has tonight.
class ActorState {
  final List<String> cards;
  final List<String> used;
  final String? current;

  const ActorState({required this.cards, this.used = const [], this.current});

  /// The cards he can still choose from.
  List<String> get available => [
    for (final c in cards)
      if (!used.contains(c)) c,
  ];

  ActorState copyWith({List<String>? used, Object? current = _unset}) => ActorState(
    cards: cards,
    used: used ?? this.used,
    current: identical(current, _unset) ? this.current : current as String?,
  );
}

class LoversPair {
  final String playerAId;
  final String playerBId;

  const LoversPair(this.playerAId, this.playerBId);

  /// The other lover's id, or null if [playerId] is neither of them.
  String? partnerOf(String playerId) {
    if (playerId == playerAId) return playerBId;
    if (playerId == playerBId) return playerAId;
    return null;
  }
}

/// Sentinel for [GameState.copyWith]'s nullable fields, so a caller can
/// distinguish "leave unchanged" (the default) from "set to null"
/// (pass `null` explicitly), which a plain `field ?? this.field` can't do.
const _unset = Object();

class GameState {
  final List<Player> players;

  /// 1-based, same convention as NightScriptBuilder.
  final int nightIndex;
  final GamePhase phase;

  /// Null until Cupidon acts.
  final LoversPair? lovers;
  final WitchState witch;
  final String? captainPlayerId;

  /// Set by WolvesTarget, cleared by FinalizeNight.
  final String? pendingWolfVictimId;

  /// Set by WitchDeathPotion, cleared by FinalizeNight.
  final String? pendingWitchDeathTargetId;

  /// The Big Bad Wolf's second victim, set by BigBadWolfTarget, cleared by FinalizeNight.
  final String? pendingBigBadWolfVictimId;

  /// The wolf the White Werewolf ate on his solo night, set by WhiteWolfEat, cleared by
  /// FinalizeNight.
  final String? pendingWhiteWolfVictimId;

  /// Null until the Wild Child picks his role model.
  final WildChildState? wildChild;

  /// The player the Defender protects tonight, set by DefenderProtect and cleared by FinalizeNight.
  final String? defenderProtectedId;

  /// Who the Defender protected last night: he may not protect them again.
  final String? defenderLastProtectedId;

  /// Elders who already survived a first bite (a wolf attack or the Cursed Wolf-Father's).
  final Set<String> woundedElders;

  /// The villagers lost their special powers: an Elder was eliminated by the village, the Witch's
  /// poison or the Hunter's shot.
  final bool villagersPowerless;

  /// The wolf the dead Knight left diseased, until it dies.
  final KnightWound? knightWound;

  /// Who the dead Scapegoat let vote on a coming day, until that day is over.
  final VoteRestriction? voteRestriction;

  /// The two groups of the village, once the MJ divided it for the Abominable Sectaire.
  final VillageDivision? division;

  /// The role the Servante Devouee took over, once she did.
  final ServantTakeover? servantTakeover;

  /// The Comedien's cards, once the MJ laid them down.
  final ActorState? actor;

  /// Non-null exactly while a death cascade is paused on a Hunter/Captain
  /// choice only the MJ can make.
  final CascadeState? cascade;

  /// Roles whose power is gone for good (the Fox who sniffed out no wolf), with the night they
  /// lost it. The night script stops calling such a role from the night after: tonight's script
  /// must not change under the MJ's feet. See [spentPowersBeforeTonight].
  final Map<String, int> spentPowers;

  const GameState({
    required this.players,
    required this.nightIndex,
    required this.phase,
    this.lovers,
    this.witch = const WitchState(),
    this.captainPlayerId,
    this.pendingWolfVictimId,
    this.pendingWitchDeathTargetId,
    this.pendingBigBadWolfVictimId,
    this.pendingWhiteWolfVictimId,
    this.wildChild,
    this.defenderProtectedId,
    this.defenderLastProtectedId,
    this.woundedElders = const {},
    this.villagersPowerless = false,
    this.knightWound,
    this.voteRestriction,
    this.division,
    this.servantTakeover,
    this.actor,
    this.cascade,
    this.spentPowers = const {},
  });

  /// The roles whose power was already gone when tonight began.
  Set<String> get spentPowersBeforeTonight => {
    for (final entry in spentPowers.entries)
      if (entry.value < nightIndex) entry.key,
  };

  factory GameState.initial({required List<Player> players}) =>
      GameState(players: players, nightIndex: 1, phase: GamePhase.night);

  Player playerById(String id) =>
      players.firstWhereOrNull((p) => p.id == id) ?? (throw PlayerNotFoundException(id));

  /// The wolves' victim as the Witch is shown it: nobody when the Defender protects the player the
  /// wolves picked (the protection does not stop an infection, which acts on [pendingWolfVictimId]).
  String? get wolfVictimForWitch =>
      pendingWolfVictimId != null && pendingWolfVictimId == defenderProtectedId
      ? null
      : pendingWolfVictimId;

  /// The living players who may vote today, or null when everyone but the pardoned Idiot may: the
  /// Scapegoat's choice, while it applies to the day being played.
  Set<String>? get votersToday {
    final restriction = voteRestriction;
    if (restriction == null || phase != GamePhase.day || restriction.day != nightIndex) {
      return null;
    }
    return {
      for (final p in alivePlayers)
        if (restriction.allowed.contains(p.id)) p.id,
    };
  }

  /// Whether the Wandering Judge called for a second vote today.
  bool get secondVoteToday => phase == GamePhase.day && spentPowers['juge_begue'] == nightIndex;

  List<Player> get alivePlayers => players.where((p) => p.alive).toList(growable: false);

  /// Marks [playerId] as dead and stamps how and when (the current
  /// [nightIndex] and [phase]). Does not resolve any cascade effects; that's
  /// the death cascade's job (see death_cascade.dart).
  GameState killPlayer(String playerId, {required DeathCause cause}) {
    playerById(playerId); // validates existence
    // The Wild Child becomes a werewolf the moment his role model is eliminated, whatever the way.
    final turnsWildChild = wildChild != null && wildChild!.modelId == playerId;
    // Eliminating the Elder (vote, poison, Hunter's shot) costs the villagers their powers. Not
    // the wolves (his two lives), nor the grief of a lover.
    final eldersLoss =
        playerById(playerId).roleId == 'ancien' &&
        (cause is DayVoteKill || cause is WitchDeathPotionKill || cause is HunterShotKill);
    return copyWith(
      villagersPowerless: villagersPowerless || eldersLoss,
      players: [
        for (final p in players)
          if (p.id == playerId)
            p.copyWith(
              alive: false,
              causeOfDeath: cause,
              diedOnNight: nightIndex,
              diedOnPhase: phase,
            )
          else if (turnsWildChild && p.id == wildChild!.childId && p.alive)
            p.copyWith(teamOverride: Team.werewolves)
          else
            p,
      ],
    );
  }

  GameState copyWith({
    List<Player>? players,
    int? nightIndex,
    GamePhase? phase,
    Object? lovers = _unset,
    WitchState? witch,
    Object? captainPlayerId = _unset,
    Object? pendingWolfVictimId = _unset,
    Object? pendingWitchDeathTargetId = _unset,
    Object? pendingBigBadWolfVictimId = _unset,
    Object? pendingWhiteWolfVictimId = _unset,
    Object? wildChild = _unset,
    Object? defenderProtectedId = _unset,
    Object? defenderLastProtectedId = _unset,
    Set<String>? woundedElders,
    bool? villagersPowerless,
    Object? knightWound = _unset,
    Object? voteRestriction = _unset,
    Object? division = _unset,
    Object? servantTakeover = _unset,
    Object? actor = _unset,
    Object? cascade = _unset,
    Map<String, int>? spentPowers,
  }) => GameState(
    players: players ?? this.players,
    nightIndex: nightIndex ?? this.nightIndex,
    phase: phase ?? this.phase,
    lovers: identical(lovers, _unset) ? this.lovers : lovers as LoversPair?,
    witch: witch ?? this.witch,
    captainPlayerId: identical(captainPlayerId, _unset)
        ? this.captainPlayerId
        : captainPlayerId as String?,
    pendingWolfVictimId: identical(pendingWolfVictimId, _unset)
        ? this.pendingWolfVictimId
        : pendingWolfVictimId as String?,
    pendingWitchDeathTargetId: identical(pendingWitchDeathTargetId, _unset)
        ? this.pendingWitchDeathTargetId
        : pendingWitchDeathTargetId as String?,
    pendingBigBadWolfVictimId: identical(pendingBigBadWolfVictimId, _unset)
        ? this.pendingBigBadWolfVictimId
        : pendingBigBadWolfVictimId as String?,
    pendingWhiteWolfVictimId: identical(pendingWhiteWolfVictimId, _unset)
        ? this.pendingWhiteWolfVictimId
        : pendingWhiteWolfVictimId as String?,
    wildChild: identical(wildChild, _unset) ? this.wildChild : wildChild as WildChildState?,
    defenderProtectedId: identical(defenderProtectedId, _unset)
        ? this.defenderProtectedId
        : defenderProtectedId as String?,
    defenderLastProtectedId: identical(defenderLastProtectedId, _unset)
        ? this.defenderLastProtectedId
        : defenderLastProtectedId as String?,
    woundedElders: woundedElders ?? this.woundedElders,
    villagersPowerless: villagersPowerless ?? this.villagersPowerless,
    knightWound: identical(knightWound, _unset) ? this.knightWound : knightWound as KnightWound?,
    voteRestriction: identical(voteRestriction, _unset)
        ? this.voteRestriction
        : voteRestriction as VoteRestriction?,
    division: identical(division, _unset) ? this.division : division as VillageDivision?,
    servantTakeover: identical(servantTakeover, _unset)
        ? this.servantTakeover
        : servantTakeover as ServantTakeover?,
    actor: identical(actor, _unset) ? this.actor : actor as ActorState?,
    cascade: identical(cascade, _unset) ? this.cascade : cascade as CascadeState?,
    spentPowers: spentPowers ?? this.spentPowers,
  );
}
