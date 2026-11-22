import '../models/death_effect.dart';
import '../models/team.dart';
import '../role_registry/role_registry.dart';
import 'death_cascade.dart';
import 'death_cause.dart';
import 'game_action.dart';
import 'game_event.dart';
import 'game_state.dart';
import 'pending_decision.dart';
import 'player.dart';
import 'sides.dart';

class ActionResult {
  final GameState state;
  final List<GameEvent> events;

  const ActionResult({required this.state, required this.events});
}

/// Thrown when a GameAction is not valid for the current state (wrong
/// phase/night, dead target, reused potion, etc).
class InvalidActionError implements Exception {
  final String message;
  InvalidActionError(this.message);

  @override
  String toString() => 'InvalidActionError: $message';
}

/// A pure, synchronous state transition function: it never decides
/// anything on its own, it only reacts to a GameAction the MJ reports.
class GameStateMachine {
  const GameStateMachine();

  static const _foxRoleId = 'renard';
  static const _infectRoleId = 'infect_pere_des_loups';
  static const _judgeRoleId = 'juge_begue';

  ActionResult apply({
    required GameState state,
    required GameAction action,
    required RoleRegistry roleRegistry,
  }) {
    final result = _dispatch(state, action, roleRegistry);
    // The Elder's elimination, whichever way it happened, costs the villagers their powers.
    if (!state.villagersPowerless && result.state.villagersPowerless) {
      final elder = result.state.players.firstWhere(
        (p) => p.roleId == 'ancien' && !p.alive,
        orElse: () => result.state.players.first,
      );
      return ActionResult(
        state: result.state,
        events: [...result.events, VillagersLostPowers(elderPlayerId: elder.id)],
      );
    }
    return result;
  }

  ActionResult _dispatch(GameState state, GameAction action, RoleRegistry roleRegistry) {
    if (state.cascade != null &&
        action is! HunterShoot &&
        action is! CaptainNameSuccessor &&
        action is! KnightContaminate &&
        action is! CaptainNoSuccessor &&
        action is! ScapegoatChooseVoters) {
      throw InvalidActionError(
        'A death cascade is pending a decision (${state.cascade.runtimeType}); '
        'only HunterShoot, CaptainNameSuccessor, CaptainNoSuccessor, KnightContaminate or ScapegoatChooseVoters can be applied until it resolves',
      );
    }
    switch (action) {
      case VoleurSwap():
        return _applyVoleurSwap(state, action, roleRegistry);
      case CupidonPair():
        return _applyCupidonPair(state, action);
      case FoxSniff():
        return _applyFoxSniff(state, action);
      case WildChildChooseModel():
        return _applyWildChildChooseModel(state, action);
      case ChienLoupChoose():
        return _applyChienLoupChoose(state, action);
      case InfectVictim():
        return _applyInfectVictim(state);
      case BigBadWolfTarget():
        return _applyBigBadWolfTarget(state, action);
      case WhiteWolfEat():
        return _applyWhiteWolfEat(state, action);
      case WolvesTarget():
        return _applyWolvesTarget(state, action);
      case WitchLifePotion():
        return _applyWitchLifePotion(state);
      case WitchDeathPotion():
        return _applyWitchDeathPotion(state, action);
      case ElectCaptain():
        return _applyElectCaptain(state, action);
      case StartNextNight():
        return _applyStartNextNight(state, roleRegistry);
      case PiperCharm():
        return _applyPiperCharm(state, action);
      case DefenderProtect():
        return _applyDefenderProtect(state, action);
      case JudgeSign():
        return _applyJudgeSign(state);
      case DivideVillage():
        return _applyDivideVillage(state, action);
      case CaptainNoSuccessor():
        return _applyCaptainNoSuccessor(state, roleRegistry);
      case DayVoteTie():
        return _applyDayVoteTie(state, action, roleRegistry);
      case ScapegoatChooseVoters():
        return _applyScapegoatChooseVoters(state, action, roleRegistry);
      case KnightContaminate():
        return _applyKnightContaminate(state, action, roleRegistry);
      case FinalizeNight():
        return _applyFinalizeNight(state, roleRegistry);
      case DayVoteElimination():
        return _applyDayVoteElimination(state, action, roleRegistry);
      case RevealRole():
        return _applyRevealRole(state, action, roleRegistry);
      case HunterShoot():
        return _applyHunterShoot(state, action, roleRegistry);
      case CaptainNameSuccessor():
        return _applyCaptainNameSuccessor(state, action, roleRegistry);
    }
  }

  ActionResult _applyVoleurSwap(
    GameState state,
    VoleurSwap action,
    RoleRegistry roleRegistry,
  ) {
    _requireNight(state, 1, 'Voleur can only act on night 1');
    final voleur = state.playerById(action.voleurPlayerId);
    _requireAlive(voleur, 'Voleur');

    final stolenRoleId = action.stolenRoleId;
    if (stolenRoleId != null) {
      roleRegistry.byId(stolenRoleId); // throws RoleNotFoundException if unknown
    }
    final resolvedRoleId = stolenRoleId ?? voleur.roleId;

    final updatedPlayers = [
      for (final p in state.players)
        if (p.id == voleur.id) p.copyWith(roleId: resolvedRoleId) else p,
    ];
    return ActionResult(
      state: state.copyWith(players: updatedPlayers),
      events: [VoleurSwapped(voleurPlayerId: voleur.id, newRoleId: resolvedRoleId)],
    );
  }

  ActionResult _applyCupidonPair(GameState state, CupidonPair action) {
    _requireNight(state, 1, 'Cupidon can only act on night 1');
    if (state.lovers != null) {
      throw InvalidActionError('Cupidon has already paired two players this game');
    }
    if (action.playerAId == action.playerBId) {
      throw InvalidActionError('Cupidon cannot pair a player with themselves');
    }
    _requireAlive(state.playerById(action.playerAId), 'playerA');
    _requireAlive(state.playerById(action.playerBId), 'playerB');

    return ActionResult(
      state: state.copyWith(lovers: LoversPair(action.playerAId, action.playerBId)),
      events: [LoversPaired(playerAId: action.playerAId, playerBId: action.playerBId)],
    );
  }

  ActionResult _applyFoxSniff(GameState state, FoxSniff action) {
    if (state.phase != GamePhase.night) {
      throw InvalidActionError('The Fox can only sniff during the night');
    }
    if (state.spentPowers.containsKey(_foxRoleId)) {
      throw InvalidActionError('The Fox has lost his power');
    }
    _requireAlive(state.playerById(action.middlePlayerId), 'the Fox\'s middle player');

    return ActionResult(
      state: action.wolfFound
          ? state
          : state.copyWith(
              spentPowers: {...state.spentPowers, _foxRoleId: state.nightIndex},
            ),
      events: [
        FoxSniffed(middlePlayerId: action.middlePlayerId, wolfFound: action.wolfFound),
      ],
    );
  }

  ActionResult _applyWildChildChooseModel(GameState state, WildChildChooseModel action) {
    _requireNightPhase(state, 'The Wild Child picks his role model');
    _requireAlive(state.playerById(action.childPlayerId), 'the Wild Child');
    _requireAlive(state.playerById(action.modelPlayerId), 'the role model');
    if (action.childPlayerId == action.modelPlayerId) {
      throw InvalidActionError('The Wild Child cannot be his own role model');
    }
    return ActionResult(
      state: state.copyWith(
        wildChild: WildChildState(
          childId: action.childPlayerId,
          modelId: action.modelPlayerId,
        ),
      ),
      events: [
        WildChildModelChosen(
          childPlayerId: action.childPlayerId,
          modelPlayerId: action.modelPlayerId,
        ),
      ],
    );
  }

  ActionResult _applyChienLoupChoose(GameState state, ChienLoupChoose action) {
    _requireNightPhase(state, 'The Wolf-Hound chooses at night');
    final dog = state.playerById(action.playerId);
    _requireAlive(dog, 'the Wolf-Hound');
    if (dog.teamOverride != null) {
      throw InvalidActionError('The Wolf-Hound has already chosen: the choice is final');
    }
    return ActionResult(
      state: state.copyWith(
        players: [
          for (final p in state.players)
            if (p.id == dog.id)
              p.copyWith(teamOverride: action.wolf ? Team.werewolves : Team.village)
            else
              p,
        ],
      ),
      events: [ChienLoupChose(playerId: dog.id, wolf: action.wolf)],
    );
  }

  ActionResult _applyInfectVictim(GameState state) {
    _requireNightPhase(state, 'The Cursed Wolf-Father infects at night');
    if (state.spentPowers.containsKey(_infectRoleId)) {
      throw InvalidActionError('The Cursed Wolf-Father has already infected someone');
    }
    final victimId = state.pendingWolfVictimId;
    if (victimId == null) {
      throw InvalidActionError('No wolf victim to infect');
    }
    final bitten = state.playerById(victimId);
    _requireAlive(bitten, 'the infected player');
    // The Elder is not affected by the first bite: it is spent, and he keeps his other life.
    if (bitten.roleId == 'ancien' && !state.woundedElders.contains(victimId)) {
      return ActionResult(
        state: state.copyWith(
          pendingWolfVictimId: null,
          woundedElders: {...state.woundedElders, victimId},
          spentPowers: {...state.spentPowers, _infectRoleId: state.nightIndex},
        ),
        events: [ElderSurvived(playerId: victimId)],
      );
    }
    return ActionResult(
      state: state.copyWith(
        pendingWolfVictimId: null,
        players: [
          for (final p in state.players)
            if (p.id == victimId)
              p.copyWith(
                teamOverride: Team.werewolves,
                statuses: {...p.statuses, PlayerStatus.infected},
              )
            else
              p,
        ],
        spentPowers: {...state.spentPowers, _infectRoleId: state.nightIndex},
      ),
      events: [VictimInfected(playerId: victimId)],
    );
  }

  ActionResult _applyBigBadWolfTarget(GameState state, BigBadWolfTarget action) {
    _requireNightPhase(state, 'The Big Bad Wolf eats at night');
    _requireAlive(state.playerById(action.targetPlayerId), 'the Big Bad Wolf\'s target');
    return ActionResult(
      state: state.copyWith(pendingBigBadWolfVictimId: action.targetPlayerId),
      events: const [],
    );
  }

  ActionResult _applyWhiteWolfEat(GameState state, WhiteWolfEat action) {
    _requireNightPhase(state, 'The White Werewolf eats at night');
    _requireAlive(state.playerById(action.targetPlayerId), 'the White Werewolf\'s target');
    return ActionResult(
      state: state.copyWith(pendingWhiteWolfVictimId: action.targetPlayerId),
      events: const [],
    );
  }

  ActionResult _applyWolvesTarget(GameState state, WolvesTarget action) {
    _requireAlive(state.playerById(action.targetPlayerId), 'wolves target');
    return ActionResult(
      state: state.copyWith(pendingWolfVictimId: action.targetPlayerId),
      events: const [],
    );
  }

  ActionResult _applyWitchLifePotion(GameState state) {
    if (state.witch.lifePotionUsed) {
      throw InvalidActionError('Witch has already used her life potion');
    }
    if (state.pendingWolfVictimId == null) {
      throw InvalidActionError('No wolf victim to save');
    }
    return ActionResult(
      state: state.copyWith(
        pendingWolfVictimId: null,
        witch: state.witch.copyWith(lifePotionUsed: true),
      ),
      events: const [WitchLifePotionUsed()],
    );
  }

  ActionResult _applyWitchDeathPotion(GameState state, WitchDeathPotion action) {
    if (state.witch.deathPotionUsed) {
      throw InvalidActionError('Witch has already used her death potion');
    }
    _requireAlive(state.playerById(action.targetPlayerId), 'witch death potion target');

    return ActionResult(
      state: state.copyWith(
        pendingWitchDeathTargetId: action.targetPlayerId,
        witch: state.witch.copyWith(deathPotionUsed: true),
      ),
      events: [WitchDeathPotionUsed(targetPlayerId: action.targetPlayerId)],
    );
  }

  ActionResult _applyElectCaptain(GameState state, ElectCaptain action) {
    if (state.phase != GamePhase.day) {
      throw InvalidActionError('Captain can only be elected during the day');
    }
    if (state.captainPlayerId != null) {
      throw InvalidActionError('A captain has already been elected');
    }
    _requireAlive(state.playerById(action.playerId), 'captain candidate');

    return ActionResult(
      state: state.copyWith(captainPlayerId: action.playerId),
      events: [CaptainElected(playerId: action.playerId)],
    );
  }

  ActionResult _applyFinalizeNight(GameState state, RoleRegistry roleRegistry) {
    if (state.phase != GamePhase.night) {
      throw InvalidActionError('Can only finalize the night during the night phase');
    }
    var currentState = state;
    final events = <GameEvent>[];
    final queue = <CascadeTask>[];

    // The Elder survives the first time the wolves devour him (the table is not told).
    String? spareElder(String? victimId) {
      if (victimId == null) return null;
      final victim = currentState.playerById(victimId);
      if (victim.alive &&
          victim.roleId == 'ancien' &&
          !currentState.woundedElders.contains(victimId)) {
        currentState = currentState.copyWith(
          woundedElders: {...currentState.woundedElders, victimId},
        );
        events.add(ElderSurvived(playerId: victimId));
        return null;
      }
      return victimId;
    }

    // What the Defender protects tonight is not eaten by the wolves (nor by the Big Bad Wolf).
    String? shield(String? victimId) {
      if (victimId != null && victimId == state.defenderProtectedId) {
        events.add(DefenderSaved(playerId: victimId));
        return null;
      }
      return victimId;
    }

    final wolfVictim = spareElder(shield(state.pendingWolfVictimId));
    final bigBadVictim = spareElder(shield(state.pendingBigBadWolfVictimId));

    // The wolf the Knight's sword wounded, when the disease strikes at the end of the night.
    final wound = state.knightWound;
    final diseased = wound != null && wound.atNightEnd && wound.dueNight <= state.nightIndex
        ? wound.wolfId
        : null;

    final pendingKills = <(String, DeathCause)>[
      if (wolfVictim != null) (wolfVictim, const WolvesKill()),
      if (bigBadVictim != null) (bigBadVictim, const WolvesKill()),
      if (state.pendingWhiteWolfVictimId != null)
        (state.pendingWhiteWolfVictimId!, const WhiteWolfKill()),
      if (state.pendingWitchDeathTargetId != null)
        (state.pendingWitchDeathTargetId!, const WitchDeathPotionKill()),
      if (diseased != null) (diseased, const DiseaseKill()),
    ];
    for (final (playerId, cause) in pendingKills) {
      if (!currentState.playerById(playerId).alive) {
        continue; // dedupes an identical wolf/witch target: already killed above
      }
      currentState = currentState.killPlayer(playerId, cause: cause);
      events.add(PlayerDied(playerId: playerId, cause: cause));
      queue.addAll(deathCascadeTasks(playerId));
    }

    final drained = drainCascade(state: currentState, queue: queue, roleRegistry: roleRegistry);
    events
      ..addAll(drained.events)
      ..add(NightFinalized(nightIndex: state.nightIndex));

    return ActionResult(
      state: drained.state.copyWith(
        phase: GamePhase.day,
        pendingWolfVictimId: null,
        pendingWitchDeathTargetId: null,
        pendingBigBadWolfVictimId: null,
        pendingWhiteWolfVictimId: null,
        defenderProtectedId: null,
        defenderLastProtectedId: state.defenderProtectedId,
        knightWound: diseased != null ? null : drained.state.knightWound,
        cascade: drained.pendingDecision == null
            ? null
            : CascadeState(decision: drained.pendingDecision!, remainingQueue: drained.remainingQueue),
      ),
      events: events,
    );
  }

  ActionResult _applyDayVoteElimination(
    GameState state,
    DayVoteElimination action,
    RoleRegistry roleRegistry,
  ) {
    if (state.phase != GamePhase.day) {
      throw InvalidActionError('Day vote elimination can only happen during the day');
    }
    final target = state.playerById(action.targetPlayerId);
    _requireAlive(target, 'day vote target');

    // The Village Idiot shows his card and is pardoned, once: nobody is eliminated.
    if (target.roleId == 'idiot_du_village' && !target.hasStatus(PlayerStatus.pardoned)) {
      return ActionResult(
        state: state.copyWith(
          players: [
            for (final p in state.players)
              if (p.id == target.id)
                p.copyWith(statuses: {...p.statuses, PlayerStatus.pardoned})
              else
                p,
          ],
        ),
        events: [IdiotPardoned(playerId: target.id)],
      );
    }

    final killed = state.killPlayer(action.targetPlayerId, cause: const DayVoteKill());
    final events = <GameEvent>[
      PlayerDied(playerId: action.targetPlayerId, cause: const DayVoteKill()),
    ];
    final drained = drainCascade(
      state: killed,
      queue: deathCascadeTasks(action.targetPlayerId),
      roleRegistry: roleRegistry,
    );
    events.addAll(drained.events);

    return ActionResult(
      state: drained.state.copyWith(
        cascade: drained.pendingDecision == null
            ? null
            : CascadeState(decision: drained.pendingDecision!, remainingQueue: drained.remainingQueue),
      ),
      events: events,
    );
  }

  ActionResult _applyRevealRole(
    GameState state,
    RevealRole action,
    RoleRegistry roleRegistry,
  ) {
    final player = state.playerById(action.playerId);
    final role = roleRegistry.byId(action.roleId); // throws if the role id is unknown

    // An Elder eliminated by the village, the poison or the Hunter's shot whose card is only now
    // known: the villagers lose their powers now.
    final cause = player.causeOfDeath;
    final eldersLoss =
        !player.alive &&
        action.roleId == 'ancien' &&
        (cause is DayVoteKill || cause is WitchDeathPotionKill || cause is HunterShotKill);
    final revealed = state.copyWith(
      villagersPowerless: state.villagersPowerless || eldersLoss,
      players: [
        for (final p in state.players)
          if (p.id == player.id) p.copyWith(roleId: action.roleId) else p,
      ],
    );
    final events = <GameEvent>[RoleRevealed(playerId: player.id, roleId: action.roleId)];

    // A living player just gets the write. A dead one may now trigger their
    // on-death effect: the cascade that ran when they died saw the placeholder
    // role and skipped it. Their captain status and lovers link were
    // role-independent and are already resolved, so only ResolveOnDeathEffect
    // is replayed here.
    if (!player.alive && role.onDeath != DeathEffect.none) {
      final drained = drainCascade(
        state: revealed,
        queue: [ResolveOnDeathEffect(player.id)],
        roleRegistry: roleRegistry,
      );
      events.addAll(drained.events);
      return ActionResult(
        state: drained.state.copyWith(
          cascade: drained.pendingDecision == null
              ? null
              : CascadeState(
                  decision: drained.pendingDecision!,
                  remainingQueue: drained.remainingQueue,
                ),
        ),
        events: events,
      );
    }

    return ActionResult(state: revealed, events: events);
  }

  ActionResult _applyStartNextNight(GameState state, RoleRegistry roleRegistry) {
    if (state.phase != GamePhase.day) {
      throw InvalidActionError('Can only start the next night from the day phase');
    }
    final night = state.copyWith(nightIndex: state.nightIndex + 1, phase: GamePhase.night);

    // The wolf the Knight's sword wounded dies as the night begins (unless the setting puts it
    // at the end, see FinalizeNight).
    final wound = night.knightWound;
    if (wound == null || wound.atNightEnd || wound.dueNight > night.nightIndex) {
      return ActionResult(state: night, events: const []);
    }
    final cleared = night.copyWith(knightWound: null);
    if (!cleared.playerById(wound.wolfId).alive) {
      return ActionResult(state: cleared, events: const []);
    }
    const cause = DiseaseKill();
    final killed = cleared.killPlayer(wound.wolfId, cause: cause);
    final drained = drainCascade(
      state: killed,
      queue: deathCascadeTasks(wound.wolfId),
      roleRegistry: roleRegistry,
    );
    return ActionResult(
      state: drained.state.copyWith(
        cascade: drained.pendingDecision == null
            ? null
            : CascadeState(
                decision: drained.pendingDecision!,
                remainingQueue: drained.remainingQueue,
              ),
      ),
      events: [PlayerDied(playerId: wound.wolfId, cause: cause), ...drained.events],
    );
  }

  ActionResult _applyDivideVillage(GameState state, DivideVillage action) {
    _requireNight(state, 1, 'The village is divided before the first night');
    final ids = action.groupAPlayerIds;
    for (final id in ids) {
      state.playerById(id); // validates existence
    }
    if (ids.isEmpty || ids.length >= state.players.length) {
      throw InvalidActionError('Both groups need at least one player');
    }
    return ActionResult(
      state: state.copyWith(division: VillageDivision(groupA: {...ids})),
      events: [VillageDivided(groupAPlayerIds: {...ids})],
    );
  }

  ActionResult _applyJudgeSign(GameState state) {
    if (state.phase != GamePhase.day) {
      throw InvalidActionError('The Wandering Judge gives his sign during a village vote');
    }
    if (state.villagersPowerless) {
      throw InvalidActionError('The villagers have lost their powers');
    }
    if (state.spentPowers.containsKey(_judgeRoleId)) {
      throw InvalidActionError('The Wandering Judge already used his sign');
    }
    if (!state.players.any((p) => p.alive && p.roleId == _judgeRoleId)) {
      throw InvalidActionError('There is no living Wandering Judge');
    }
    return ActionResult(
      state: state.copyWith(spentPowers: {...state.spentPowers, _judgeRoleId: state.nightIndex}),
      events: const [JudgeSignGiven()],
    );
  }

  ActionResult _applyDefenderProtect(GameState state, DefenderProtect action) {
    _requireNightPhase(state, 'The Defender protects at night');
    _requireAlive(state.playerById(action.targetPlayerId), 'the protected player');
    if (action.targetPlayerId == state.defenderLastProtectedId) {
      throw InvalidActionError('The Defender cannot protect the same player two nights in a row');
    }
    return ActionResult(
      state: state.copyWith(defenderProtectedId: action.targetPlayerId),
      events: const [],
    );
  }

  ActionResult _applyPiperCharm(GameState state, PiperCharm action) {
    _requireNightPhase(state, 'The Piper charms at night');
    final ids = action.playerIds;
    if (ids.isEmpty || ids.length > 2 || ids.toSet().length != ids.length) {
      throw InvalidActionError('The Piper charms one or two different players');
    }
    for (final id in ids) {
      final player = state.playerById(id);
      _requireAlive(player, 'a charmed player');
      if (player.roleId == 'joueur_de_flute') {
        throw InvalidActionError('The Piper cannot charm himself');
      }
      if (player.hasStatus(PlayerStatus.charmed)) {
        throw InvalidActionError('${player.id} is already charmed');
      }
    }
    return ActionResult(
      state: state.copyWith(
        players: [
          for (final p in state.players)
            if (ids.contains(p.id))
              p.copyWith(statuses: {...p.statuses, PlayerStatus.charmed})
            else
              p,
        ],
      ),
      events: [PlayersCharmed(playerIds: ids)],
    );
  }

  ActionResult _applyKnightContaminate(
    GameState state,
    KnightContaminate action,
    RoleRegistry roleRegistry,
  ) {
    final cascade = state.cascade;
    if (cascade == null || cascade.decision is! PendingKnightWound) {
      throw InvalidActionError('No pending Knight wound to resolve');
    }
    final events = <GameEvent>[];
    var next = state.copyWith(cascade: null);
    final wolfId = action.wolfPlayerId;
    if (wolfId != null) {
      final wolf = state.playerById(wolfId);
      _requireAlive(wolf, 'the diseased wolf');
      if (!wolf.wakesWithWolvesIn(roleRegistry)) {
        throw InvalidActionError('The Knight\'s sword wounds a wolf, not $wolfId');
      }
      next = next.copyWith(
        knightWound: KnightWound(
          wolfId: wolfId,
          dueNight: state.nightIndex + 1,
          atNightEnd: action.atNightEnd,
        ),
      );
      events.add(KnightContaminated(wolfPlayerId: wolfId));
    }
    final drained = drainCascade(
      state: next,
      queue: cascade.remainingQueue,
      roleRegistry: roleRegistry,
    );
    events.addAll(drained.events);
    return ActionResult(
      state: drained.state.copyWith(
        cascade: drained.pendingDecision == null
            ? null
            : CascadeState(
                decision: drained.pendingDecision!,
                remainingQueue: drained.remainingQueue,
              ),
      ),
      events: events,
    );
  }

  ActionResult _applyHunterShoot(
    GameState state,
    HunterShoot action,
    RoleRegistry roleRegistry,
  ) {
    final cascade = state.cascade;
    if (cascade == null) {
      throw InvalidActionError('No pending Hunter shot to resolve');
    }
    if (cascade.decision case PendingHunterShot(:final deadHunterId)) {
      final target = action.targetPlayerId;
      final events = <GameEvent>[];
      final GameState afterShot;
      final List<CascadeTask> resumedQueue;

      if (target == null) {
        // "Il ne tire pas": no kill, just resume whatever was queued behind
        // the paused decision (the hunter's own captain status / lovers link).
        events.add(HunterShotSkipped(hunterPlayerId: deadHunterId));
        afterShot = state.copyWith(cascade: null);
        resumedQueue = cascade.remainingQueue;
      } else {
        _requireAlive(state.playerById(target), 'hunter shot target');
        afterShot = state
            .killPlayer(target, cause: HunterShotKill(shooterPlayerId: deadHunterId))
            .copyWith(cascade: null);
        events
          ..add(PlayerDied(playerId: target, cause: HunterShotKill(shooterPlayerId: deadHunterId)))
          ..add(HunterShotFired(hunterPlayerId: deadHunterId, targetPlayerId: target));
        resumedQueue = [...cascade.remainingQueue, ...deathCascadeTasks(target)];
      }

      final drained = drainCascade(
        state: afterShot,
        queue: resumedQueue,
        roleRegistry: roleRegistry,
      );
      events.addAll(drained.events);

      return ActionResult(
        state: drained.state.copyWith(
          cascade: drained.pendingDecision == null
              ? null
              : CascadeState(decision: drained.pendingDecision!, remainingQueue: drained.remainingQueue),
        ),
        events: events,
      );
    }
    throw InvalidActionError('No pending Hunter shot to resolve');
  }

  ActionResult _applyDayVoteTie(GameState state, DayVoteTie action, RoleRegistry roleRegistry) {
    if (state.phase != GamePhase.day) {
      throw InvalidActionError('A tied vote can only happen during the day');
    }
    final scapegoatId = action.scapegoatPlayerId;
    if (scapegoatId == null) return ActionResult(state: state, events: const []);

    final scapegoat = state.playerById(scapegoatId);
    _requireAlive(scapegoat, 'the Scapegoat');
    if (scapegoat.roleId != 'bouc_emissaire' || state.villagersPowerless) {
      throw InvalidActionError('$scapegoatId cannot take the blame of a tied vote');
    }
    final killed = state.killPlayer(scapegoatId, cause: const DayVoteKill());
    final drained = drainCascade(
      state: killed,
      queue: deathCascadeTasks(scapegoatId),
      roleRegistry: roleRegistry,
    );
    return ActionResult(
      state: drained.state.copyWith(
        cascade: drained.pendingDecision == null
            ? null
            : CascadeState(
                decision: drained.pendingDecision!,
                remainingQueue: drained.remainingQueue,
              ),
      ),
      events: [
        ScapegoatBlamed(playerId: scapegoatId),
        PlayerDied(playerId: scapegoatId, cause: const DayVoteKill()),
        ...drained.events,
      ],
    );
  }

  ActionResult _applyScapegoatChooseVoters(
    GameState state,
    ScapegoatChooseVoters action,
    RoleRegistry roleRegistry,
  ) {
    final cascade = state.cascade;
    if (cascade == null || cascade.decision is! PendingScapegoatVoters) {
      throw InvalidActionError('No pending Scapegoat choice to resolve');
    }
    final dead = state.playerById((cascade.decision as PendingScapegoatVoters).deadScapegoatId);
    for (final id in action.allowedPlayerIds) {
      state.playerById(id); // validates existence
    }
    // "The next day": the one that follows his death - this very morning when he died at night,
    // tomorrow when he died in a day.
    final day = dead.diedOnPhase == GamePhase.night ? dead.diedOnNight! : dead.diedOnNight! + 1;
    final drained = drainCascade(
      state: state.copyWith(
        cascade: null,
        voteRestriction: VoteRestriction(allowed: action.allowedPlayerIds, day: day),
      ),
      queue: cascade.remainingQueue,
      roleRegistry: roleRegistry,
    );
    return ActionResult(
      state: drained.state.copyWith(
        cascade: drained.pendingDecision == null
            ? null
            : CascadeState(
                decision: drained.pendingDecision!,
                remainingQueue: drained.remainingQueue,
              ),
      ),
      events: [VotersChosen(allowedPlayerIds: action.allowedPlayerIds), ...drained.events],
    );
  }

  ActionResult _applyCaptainNoSuccessor(GameState state, RoleRegistry roleRegistry) {
    final cascade = state.cascade;
    if (cascade == null || cascade.decision is! PendingCaptainSuccession) {
      throw InvalidActionError('No pending Captain succession to resolve');
    }
    final dead = (cascade.decision as PendingCaptainSuccession).deadCaptainId;
    final drained = drainCascade(
      state: state.copyWith(captainPlayerId: null, cascade: null),
      queue: cascade.remainingQueue,
      roleRegistry: roleRegistry,
    );
    return ActionResult(
      state: drained.state.copyWith(
        cascade: drained.pendingDecision == null
            ? null
            : CascadeState(
                decision: drained.pendingDecision!,
                remainingQueue: drained.remainingQueue,
              ),
      ),
      events: [CaptainSuccessionSkipped(deadCaptainId: dead), ...drained.events],
    );
  }

  ActionResult _applyCaptainNameSuccessor(
    GameState state,
    CaptainNameSuccessor action,
    RoleRegistry roleRegistry,
  ) {
    final cascade = state.cascade;
    if (cascade == null) {
      throw InvalidActionError('No pending Captain succession to resolve');
    }
    if (cascade.decision case PendingCaptainSuccession(:final deadCaptainId)) {
      _requireAlive(state.playerById(action.successorPlayerId), 'captain successor');

      final events = <GameEvent>[
        CaptainSuccession(fromPlayerId: deadCaptainId, toPlayerId: action.successorPlayerId),
      ];

      final newState = state.copyWith(captainPlayerId: action.successorPlayerId, cascade: null);
      final drained = drainCascade(
        state: newState,
        queue: cascade.remainingQueue,
        roleRegistry: roleRegistry,
      );
      events.addAll(drained.events);

      return ActionResult(
        state: drained.state.copyWith(
          cascade: drained.pendingDecision == null
              ? null
              : CascadeState(decision: drained.pendingDecision!, remainingQueue: drained.remainingQueue),
        ),
        events: events,
      );
    }
    throw InvalidActionError('No pending Captain succession to resolve');
  }

  void _requireNightPhase(GameState state, String what) {
    if (state.phase != GamePhase.night) {
      throw InvalidActionError('$what only during the night');
    }
  }

  void _requireAlive(Player player, String label) {
    if (!player.alive) {
      throw InvalidActionError('$label (${player.id}) is not alive');
    }
  }

  void _requireNight(GameState state, int nightIndex, String message) {
    if (state.nightIndex != nightIndex) {
      throw InvalidActionError(message);
    }
  }
}
