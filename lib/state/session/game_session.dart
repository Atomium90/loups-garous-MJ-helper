import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../data/database/app_database.dart';
import '../../data/models/game_winner.dart';
import '../../data/models/night_log_entry.dart';
import '../../data/repositories/game_not_found_exception.dart';
import '../providers/game_repository_provider.dart';
import '../settings/settings_providers.dart';
import 'night_log_entry.dart';
import 'day_plan.dart';
import 'night_script.dart';
import 'victory_proposal.dart';
import 'session_cursor.dart';

part 'game_session.g.dart';

/// The interrupt that must be cleared before the current [DayStage] body shows:
/// a dead player's card to reveal, a chain effect to resolve, or a lover's
/// grief death to acknowledge. Priority order, highest first.
enum DayInterrupt { reveal, chain, loversAck }

/// Everything a running game's screens read: the engine truth, where we are in
/// tonight's script and in the day, that script, the composition it was built
/// from, and the roster (the source of truth for which cards are confirmed).
class GameSessionState {
  final GameState engine;
  final SessionCursor cursor;
  final DaySnapshot day;
  final NightScript tonight;
  final Map<String, int> composition;

  /// The Voleur's two undealt reserve cards (empty when the composition has no
  /// Voleur, or while a drawn reserve is not noted yet). His act offers these as the swap
  /// choices.
  final List<String> reserveRoleIds;

  /// The reserve is whatever two cards were left after the deal (the booklets' rule), noted by
  /// the MJ on night 1, rather than picked at the composition.
  final bool reserveDrawn;

  /// Whether the Fox is called after the Witch in this game. Fixed when the game starts, so the
  /// order never changes under the MJ's feet.
  final bool foxAfterWitch;

  /// Whether the White Werewolf's solo nights are the odd ones in this game; fixed at its start.
  final bool whiteWolfOddNights;

  final List<PlayerRow> roster;

  /// Set once the Voleur has taken a reserve card: which player he is and
  /// which role he stole. He holds a *bonus* card, not one of the dealt ones,
  /// so identify-step counting has to tell him apart from a real dealt holder
  /// the Voyante just noted.
  final ({String playerId, String roleId})? voleurSwapIn;

  const GameSessionState({
    required this.engine,
    required this.cursor,
    required this.day,
    required this.tonight,
    required this.composition,
    required this.reserveRoleIds,
    this.reserveDrawn = false,
    this.foxAfterWitch = false,
    this.whiteWolfOddNights = false,
    required this.roster,
    this.voleurSwapIn,
  });

  /// The winner the table looks to have, or null while the game plainly goes on. Offered to the
  /// MJ, never applied: only they end the game.
  GameWinner? get proposedWinner {
    final kind = proposeVictory(engine, RoleRegistry.all);
    return kind == null ? null : winnerFor(kind);
  }

  /// The living Bear Tamer, once the MJ has noted who he is.
  Player? get bearTamer =>
      engine.players.where((p) => p.alive && p.roleId == 'montreur_d_ours').firstOrNull;

  /// Whether he growls this morning, from the roles the app knows.
  bool get bearShouldGrowl {
    final bear = bearTamer;
    return bear != null && engine.bearGrowls(bear.id, RoleRegistry.all);
  }

  /// Whether the player [playerId], about to be devoured, may be the Elder: the composition has
  /// one whose card has not been noted yet, and this player's card is still unknown. The MJ is
  /// asked, since the Elder's first bite is spared and he has no call of his own to be known by.
  bool mayBeElder(String playerId) {
    final elders = dealtComposition['ancien'] ?? 0;
    if (elders == 0) return false;
    if (engine.playerById(playerId).roleId != kPlaceholderRoleId) return false;
    return engine.players.where((p) => p.roleId == 'ancien').length < elders;
  }

  /// The living Scapegoat the app knows, while the villagers keep their powers: a tied vote falls
  /// on him.
  Player? get knownScapegoat => engine.villagersPowerless
      ? null
      : engine.players.where((p) => p.alive && p.roleId == 'bouc_emissaire').firstOrNull;

  /// Whether a tied vote may fall on a Scapegoat the app does not know yet: the composition has
  /// one whose card has not been noted, and the villagers still have their powers.
  bool get scapegoatMayBeAlive {
    if (engine.villagersPowerless || knownScapegoat != null) return false;
    final goats = dealtComposition['bouc_emissaire'] ?? 0;
    return engine.players.where((p) => p.roleId == 'bouc_emissaire').length < goats;
  }

  /// Whether the player [playerId], about to be voted against, may be the Village Idiot: same
  /// logic as the Elder's, since he has no call to be known by.
  bool mayBeIdiot(String playerId) {
    final idiots = dealtComposition['idiot_du_village'] ?? 0;
    if (idiots == 0) return false;
    if (engine.playerById(playerId).roleId != kPlaceholderRoleId) return false;
    return engine.players.where((p) => p.roleId == 'idiot_du_village').length < idiots;
  }

  /// A drawn reserve the MJ has yet to note: asked for at the Voleur's step.
  bool get reserveToEnter => reserveDrawn && reserveRoleIds.isEmpty;

  /// Both reserve cards are wolves: the booklets force the Voleur to swap.
  bool get reserveForcesSwap =>
      reserveRoleIds.length == 2 &&
      reserveRoleIds.every(
        (id) => RoleRegistry.all.byIdOrNull(id)?.team == Team.werewolves,
      );

  /// The cards in the pack: the composition, plus the two Simples Villageois a drawn reserve
  /// adds. Empty unless the reserve is drawn.
  List<({String roleId, int count})> get pack {
    if (!reserveDrawn) return const [];
    final counts = {...composition};
    counts.update(kPlaceholderRoleId, (n) => n + 2, ifAbsent: () => 2);
    return [
      for (final role in RoleRegistry.all.roles)
        if ((counts[role.id] ?? 0) > 0) (roleId: role.id, count: counts[role.id]!),
    ];
  }

  /// How many holders each role really has among the players: the [composition], less the cards
  /// a drawn reserve took out of the deal.
  Map<String, int> get dealtComposition =>
      dealtCompositionOf(composition, reserveRoleIds, reserveDrawn: reserveDrawn);

  /// How many dealt holders [roleId] is expected to have. A drawn reserve that is noted makes
  /// this exact (a card in the middle has no holder); otherwise a role the composition does not
  /// list is assumed to have one.
  int expectedHolders(String roleId) => reserveDrawn && reserveRoleIds.isNotEmpty
      ? dealtComposition[roleId] ?? 0
      : composition[roleId] ?? 1;

  /// The step the cursor points at, or null once every step is done (the
  /// "ready to resolve the night" state).
  NightScriptStep? get currentStep =>
      cursor.stepIndex < tonight.steps.length ? tonight.steps[cursor.stepIndex] : null;

  bool get readyToResolve =>
      engine.phase == GamePhase.night && cursor.stepIndex >= tonight.steps.length;

  /// Whether the current step still needs its holder(s) recorded. False once
  /// the full count for the role is known (or the cursor has already moved to
  /// the action) - later nights then jump straight to the action.
  bool get currentStepNeedsIdentify {
    final step = currentStep;
    if (step == null || cursor.subStep == NightSubStep.act) return false;
    // The charmed players' call is made of whoever was charmed: nobody to identify.
    if (step.role.id == kCharmedStepRole.id) return false;
    return dealtHoldersKnown(step.role.id) < expectedHolders(step.role.id);
  }

  /// How many confirmed holders of [roleId] are one of its *dealt* cards - the
  /// Voleur's stolen card is a bonus, so it doesn't count against the deal.
  int dealtHoldersKnown(String roleId) {
    final holders = engine.players.where((p) => p.roleId == roleId).length;
    return holders - (voleurSwapIn?.roleId == roleId ? 1 : 0);
  }

  /// The Voleur, once he has swapped into [roleId] - shown as a locked cell on
  /// that role's identify grid so the MJ sees the extra holder.
  List<Player> voleurSwapInsFor(String roleId) {
    final swap = voleurSwapIn;
    if (swap == null || swap.roleId != roleId) return const [];
    final voleur = engine.playerById(swap.playerId);
    return voleur.alive ? [voleur] : const [];
  }

  /// The confirmed card for [playerId] (an engine id), or null when the MJ
  /// never recorded it. The roster is the source of truth: the engine keeps a
  /// `villageois` placeholder for any player not yet identified, so reading
  /// `engine.playerById(id).roleId` for this would silently show "Villageois".
  String? rosterRoleId(String playerId) {
    final id = int.tryParse(playerId);
    for (final r in roster) {
      if (r.id == id) return r.roleId;
    }
    return null;
  }

  /// The deaths the day recap reads aloud: everyone who died in the night just
  /// resolved. Engine-derived (each `Player` carries its cause and timing), so
  /// it survives a force-quit onto the recap.
  List<Player> get recapDeaths => engine.players
      .where(
        (p) => !p.alive && p.diedOnNight == engine.nightIndex && p.diedOnPhase == GamePhase.night,
      )
      .toList(growable: false);

  /// Dead players whose card was never recorded (roster `roleId` still null and
  /// not explicitly skipped) - each gets the reveal panel before the day can
  /// proceed.
  List<Player> get unrevealedDead {
    final unknown = {
      for (final r in roster)
        if (r.roleId == null) '${r.id}',
    };
    return engine.players
        .where(
          (p) => !p.alive && unknown.contains(p.id) && !day.revealSkipped.contains(p.id),
        )
        .toList(growable: false);
  }

  DayInterrupt? get dayInterrupt {
    // A pending cascade comes first: the engine refuses every other action
    // until it resolves. Revealing a dead player's card is what *raises* one
    // (a hidden Chasseur), so once it's set, its panel wins over the next
    // player still waiting to be revealed.
    if (engine.cascade != null) return DayInterrupt.chain;
    if (unrevealedDead.isNotEmpty) return DayInterrupt.reveal;
    if (day.loversAck.isNotEmpty) return DayInterrupt.loversAck;
    return null;
  }
}

/// The orchestrator: loads-or-seeds a game's `GameState`, applies MJ-reported
/// facts through the pure `GameStateMachine`, and persists a snapshot after
/// every change so a force-quit resumes on the exact step - including mid
/// death-cascade.
///
/// Night role identification (the blind deal) edits the engine players' roleId
/// directly; a post-mortem reveal goes through the engine's `RevealRole` so it
/// can replay the dead player's on-death effect. Un-identified players carry a
/// `villageois` placeholder in the engine; the roster's null `roleId` is the
/// real "not known yet" signal.
@riverpod
class GameSession extends _$GameSession {
  static const _placeholderRole = kPlaceholderRoleId;
  static const _machine = GameStateMachine();
  final _registry = RoleRegistry.all;

  /// Persisted in the session blob: which player the Voleur is and the reserve
  /// card he took. Null until he swaps (or if he keeps his own card).
  ({String playerId, String roleId})? _voleurSwapIn;

  /// The two leftover cards of a drawn reserve, once the MJ has noted them. Persisted in the
  /// session blob (the game's own reserve column is only for a reserve picked at composition).
  List<String> _drawnReserve = const [];

  /// The Fox's place in the call order for this game, taken from the settings when the game's
  /// session is created and kept in the snapshot.
  bool _foxAfterWitch = false;

  /// The White Werewolf's parity for this game, fixed like the Fox's place.
  bool _whiteWolfOdd = false;

  @override
  Future<GameSessionState> build(int gameId) async {
    final repo = ref.read(gameRepositoryProvider);
    final game = await repo.getGame(gameId);
    if (game == null) throw GameNotFoundException(gameId);
    final composition = game.compositionJson ?? const <String, int>{};
    final pickedReserve = game.reserveRolesJson ?? const <String>[];
    // A Voleur whose reserve was not picked at composition has it drawn.
    final reserveDrawn = composition.containsKey('voleur') && pickedReserve.isEmpty;
    final roster = await repo.getRoster(gameId);

    final GameState engine;
    final SessionCursor cursor;
    final DaySnapshot day;
    final existing = game.sessionJson;
    if (existing == null) {
      final fresh = GameState.initial(
        players: [
          for (final r in roster)
            Player(id: '${r.id}', name: r.name, roleId: r.roleId ?? _placeholderRole),
        ],
      );
      // With the Angel in play the game starts by a debate and a vote, before the first night.
      final angelInPlay = (composition['ange'] ?? 0) > 0;
      engine = angelInPlay ? fresh.copyWith(nightIndex: 0, phase: GamePhase.day) : fresh;
      cursor = SessionCursor.nightStart;
      day = angelInPlay ? const DaySnapshot(stage: DayStage.vote) : DaySnapshot.fresh;
      final settings = ref.read(settingsProvider).value;
      _foxAfterWitch = settings?.foxAfterWitch ?? false;
      _whiteWolfOdd = settings?.whiteWolfOddNights ?? false;
      await _persist(engine, cursor, day);
    } else {
      final decoded = jsonDecode(existing) as Map<String, dynamic>;
      engine = GameStateJson.decode(decoded['engine'] as Map<String, dynamic>);
      cursor = SessionCursor.fromJson(decoded['cursor'] as Map<String, dynamic>);
      day = decoded['day'] == null
          ? DaySnapshot.fresh
          : DaySnapshot.fromJson(decoded['day'] as Map<String, dynamic>);
      final voleur = decoded['voleurSwapIn'] as Map<String, dynamic>?;
      if (voleur != null) {
        _voleurSwapIn = (
          playerId: voleur['playerId'] as String,
          roleId: voleur['roleId'] as String,
        );
      }
      _drawnReserve = [
        for (final id in decoded['drawnReserve'] as List<dynamic>? ?? const []) id as String,
      ];
      _foxAfterWitch = decoded['foxAfterWitch'] == true;
      _whiteWolfOdd = decoded['whiteWolfOdd'] == true;
    }
    final reserveRoleIds = reserveDrawn ? _drawnReserve : pickedReserve;

    final tonight = buildNightScript(
      engine: engine,
      composition: composition,
      dealtComposition: dealtCompositionOf(
        composition,
        reserveRoleIds,
        reserveDrawn: reserveDrawn,
      ),
      foxAfterWitch: _foxAfterWitch,
      whiteWolfOddNights: _whiteWolfOdd,
    );
    return GameSessionState(
      engine: engine,
      cursor: _clamp(cursor, tonight),
      day: day,
      tonight: tonight,
      composition: composition,
      reserveRoleIds: reserveRoleIds,
      reserveDrawn: reserveDrawn,
      foxAfterWitch: _foxAfterWitch,
      whiteWolfOddNights: _whiteWolfOdd,
      roster: roster,
      voleurSwapIn: _voleurSwapIn,
    );
  }

  Future<void> _persist(GameState engine, SessionCursor cursor, DaySnapshot day) {
    final blob = jsonEncode({
      'engine': GameStateJson.encode(engine),
      'cursor': cursor.toJson(),
      'day': day.toJson(),
      if (_voleurSwapIn case final v?)
        'voleurSwapIn': {'playerId': v.playerId, 'roleId': v.roleId},
      if (_drawnReserve.isNotEmpty) 'drawnReserve': _drawnReserve,
      if (_foxAfterWitch) 'foxAfterWitch': true,
      if (_whiteWolfOdd) 'whiteWolfOdd': true,
    });
    return ref.read(gameRepositoryProvider).saveSession(gameId: gameId, sessionJson: blob);
  }

  Future<List<PlayerRow>> _loadRoster() =>
      ref.read(gameRepositoryProvider).getRoster(gameId);

  SessionCursor _clamp(SessionCursor c, NightScript script) => c.stepIndex <= script.steps.length
      ? c
      : SessionCursor(stepIndex: script.steps.length, subStep: NightSubStep.act);

  JournalPhase _journalPhase(GameState s) =>
      s.phase == GamePhase.night ? JournalPhase.night : JournalPhase.day;

  // --- night: identification ---

  /// Record who holds [roleId] (the night identification step) and move on to its
  /// action.
  Future<void> identifyRole(String roleId, List<int> playerRowIds) async {
    final s = state.value;
    if (s == null) return;
    await ref.read(gameRepositoryProvider).assignRoles(
      playerRowIds: playerRowIds,
      roleId: roleId,
    );
    final ids = {for (final i in playerRowIds) '$i'};
    final engine = s.engine.copyWith(
      players: [
        for (final p in s.engine.players)
          if (ids.contains(p.id)) p.copyWith(roleId: roleId) else p,
      ],
    );
    final cursor = s.cursor.copyWith(subStep: NightSubStep.act);
    final roster = await _loadRoster();
    await _persist(engine, cursor, s.day);
    _emit(s, engine: engine, cursor: cursor, roster: roster);
  }

  /// Advance past the current step with no engine action - "Je noterai plus
  /// tard" during identify, "Passer ce rôle" / "Continuer" during a role's act,
  /// or "Terminer" once the Witch is done.
  Future<void> skipStep() async {
    final s = state.value;
    if (s == null) return;
    final cursor = SessionCursor(
      stepIndex: s.cursor.stepIndex + 1,
      subStep: NightSubStep.identify,
    );
    await _persist(s.engine, cursor, s.day);
    _emit(s, cursor: cursor);
  }

  // --- night: Voyante ---

  /// The Voyante's look at one player. A peek changes no game state, so there
  /// is no engine action: just an optional note of the card ([notedRoleId] -
  /// a third way the app learns a role, like the reveal sheet but chosen), a
  /// journal line, and the cursor moves on.
  Future<void> seerInspect({required int targetRowId, String? notedRoleId}) async {
    final s = state.value;
    if (s == null) return;

    var engine = s.engine;
    var roster = s.roster;
    if (notedRoleId != null) {
      await ref.read(gameRepositoryProvider).assignRoles(
        playerRowIds: [targetRowId],
        roleId: notedRoleId,
      );
      engine = s.engine.copyWith(
        players: [
          for (final p in s.engine.players)
            if (p.id == '$targetRowId') p.copyWith(roleId: notedRoleId) else p,
        ],
      );
      roster = await _loadRoster();
    }

    await ref.read(gameRepositoryProvider).appendNightLog(
      gameId: gameId,
      entries: [
        NightLogEntry(
          phase: _journalPhase(s.engine),
          phaseIndex: s.engine.nightIndex,
          kind: JournalKind.seerObserves,
          args: {'player': engine.playerById('$targetRowId').name},
        ),
      ],
    );

    final cursor = SessionCursor(
      stepIndex: s.cursor.stepIndex + 1,
      subStep: NightSubStep.identify,
    );
    await _persist(engine, cursor, s.day);
    _emit(s, engine: engine, cursor: cursor, roster: roster);
  }

  // --- night: Voleur ---

  /// Notes the two cards left in the middle after the deal (a drawn reserve): from now on the
  /// roles that sit there have no holder to look for, and his act offers these two cards.
  Future<void> enterReserve(List<String> roleIds) async {
    final s = state.value;
    if (s == null || !s.reserveToEnter || roleIds.length != 2) return;
    _drawnReserve = List.unmodifiable(roleIds);
    await _persist(s.engine, s.cursor, s.day);
    _emit(s, reserveRoleIds: _drawnReserve);
  }

  /// The Voleur's turn: swap his card for one of the two reserve cards, or
  /// ([stolenRoleId] null) keep his own. A stolen role is written onto the
  /// roster too, so it counts as known. Refuses a [stolenRoleId] that isn't
  /// one of the reserve cards - the engine stays composition-agnostic, so the
  /// guard lives here.
  Future<void> voleurSwap({required String voleurEngineId, String? stolenRoleId}) async {
    final s = state.value;
    if (s == null) return;
    if (stolenRoleId != null && !s.reserveRoleIds.contains(stolenRoleId)) return;
    // Two wolves in the reserve: keeping his own card is not an option.
    if (stolenRoleId == null && s.reserveForcesSwap) return;
    if (stolenRoleId != null) {
      await ref.read(gameRepositoryProvider).assignRoles(
        playerRowIds: [int.parse(voleurEngineId)],
        roleId: stolenRoleId,
      );
      // Remembered so identify-step counting can tell this bonus card apart
      // from a dealt holder the Voyante just noted. Set before applyAction so
      // its _persist writes it.
      _voleurSwapIn = (playerId: voleurEngineId, roleId: stolenRoleId);
    }
    await applyAction(
      VoleurSwap(voleurPlayerId: voleurEngineId, stolenRoleId: stolenRoleId),
    );
  }

  // --- night: Renard ---

  /// The Fox sniffs around [middleEngineId]: the MJ says whether a wolf is among the three.
  /// With none his power is gone for good, which the script reads from the engine.
  Future<void> foxSniff({required String middleEngineId, required bool wolfFound}) =>
      applyAction(FoxSniff(middlePlayerId: middleEngineId, wolfFound: wolfFound));

  // --- night: the wolf camp ---

  Future<void> wildChildChoose({required String childEngineId, required String modelEngineId}) =>
      applyAction(WildChildChooseModel(childPlayerId: childEngineId, modelPlayerId: modelEngineId));

  Future<void> chienLoupChoose({required String engineId, required bool wolf}) =>
      applyAction(ChienLoupChoose(playerId: engineId, wolf: wolf));

  Future<void> infectVictim() => applyAction(const InfectVictim());

  Future<void> bigBadWolfTarget(String engineId) =>
      applyAction(BigBadWolfTarget(targetPlayerId: engineId));

  Future<void> whiteWolfEat(String engineId) =>
      applyAction(WhiteWolfEat(targetPlayerId: engineId));

  // --- night: the Piper ---

  /// The Piper charms [engineIds] (one or two players).
  Future<void> piperCharm(List<String> engineIds) =>
      applyAction(PiperCharm(playerIds: engineIds));

  // --- night: Salvateur ---

  Future<void> defenderProtect(String engineId) =>
      applyAction(DefenderProtect(targetPlayerId: engineId));

  // --- night: Deux Sœurs, Trois Frères ---

  /// The Two Sisters woke and met: a journal line, then on to the next call.
  Future<void> sistersMet() => _groupMet(JournalKind.sistersMeet);

  /// The Three Brothers woke and met.
  Future<void> brothersMet() => _groupMet(JournalKind.brothersMeet);

  Future<void> _groupMet(JournalKind kind) async {
    final s = state.value;
    if (s == null) return;
    await ref.read(gameRepositoryProvider).appendNightLog(
      gameId: gameId,
      entries: [
        NightLogEntry(
          phase: _journalPhase(s.engine),
          phaseIndex: s.engine.nightIndex,
          kind: kind,
        ),
      ],
    );
    await skipStep();
  }

  // --- night: Cupidon ---

  Future<void> pairLovers(String engineIdA, String engineIdB) =>
      applyAction(CupidonPair(playerAId: engineIdA, playerBId: engineIdB));

  // --- day: recap CTA ---

  /// The day recap's forward button: day 1 offers the captain election first,
  /// day 2+ goes straight to the vote.
  Future<void> advanceFromRecap() async {
    final s = state.value;
    if (s == null) return;
    final next = nextDayStage(DayStage.recap, s.engine);
    await _updateDay((d) => d.copyWith(stage: next));
  }

  // --- day: the Bear Tamer's growl ---

  /// The morning's growl is done: [growled] says whether the MJ growled (journalled), then the day
  /// goes on.
  Future<void> bearGrowlDone({required bool growled}) async {
    final s = state.value;
    if (s == null) return;
    if (growled) {
      await ref.read(gameRepositoryProvider).appendNightLog(
        gameId: gameId,
        entries: [
          NightLogEntry(
            phase: _journalPhase(s.engine),
            phaseIndex: s.engine.nightIndex,
            kind: JournalKind.bearGrowls,
          ),
        ],
      );
    }
    final next = nextDayStage(DayStage.growl, s.engine);
    await _updateDay((d) => d.copyWith(stage: next));
  }

  // --- day: captain election ---

  Future<void> electCaptain(String? engineId) async {
    if (engineId != null) {
      await applyAction(ElectCaptain(playerId: engineId));
    } else {
      final s = state.value;
      if (s == null) return;
      final next = nextDayStage(DayStage.captain, s.engine);
      await _updateDay((d) => d.copyWith(stage: next));
    }
  }

  // --- day: village vote ---

  Future<void> eliminateByVote(String? engineId) async {
    if (engineId != null) {
      await applyAction(DayVoteElimination(targetPlayerId: engineId));
      return;
    }
    final s = state.value;
    if (s == null) return;
    await ref.read(gameRepositoryProvider).appendNightLog(
      gameId: gameId,
      entries: [
        NightLogEntry(
          phase: _journalPhase(s.engine),
          phaseIndex: s.engine.nightIndex,
          kind: JournalKind.voteTie,
        ),
      ],
    );
    final next = nextDayStage(DayStage.vote, s.engine);
    await _updateDay((d) => d.copyWith(stage: next));
  }

  /// A tied vote with a living Scapegoat: he takes the blame in place of the tied players.
  Future<void> voteTiedOnScapegoat(String scapegoatEngineId) =>
      applyAction(DayVoteTie(scapegoatPlayerId: scapegoatEngineId));

  /// The dead Scapegoat's choice of who votes the next day.
  Future<void> chooseVoters(Set<String> allowedEngineIds) =>
      applyAction(ScapegoatChooseVoters(allowedPlayerIds: allowedEngineIds));

  // --- day: the interrupts (reveal / chain / grief) ---

  /// Post-mortem card reveal (the reveal panel). Refused while a cascade is
  /// pending - the chain panel comes first, and the engine would reject it.
  Future<void> revealRole(int rowId, String roleId) async {
    if (state.value?.engine.cascade != null) return;
    await ref.read(gameRepositoryProvider).assignRoles(playerRowIds: [rowId], roleId: roleId);
    await applyAction(RevealRole(playerId: '$rowId', roleId: roleId));
  }

  /// "Je ne note pas" on the reveal panel: leave the card unknown but stop
  /// prompting for it.
  Future<void> skipReveal(String engineId) {
    if (state.value?.engine.cascade != null) return Future.value();
    return _updateDay((d) => d.copyWith(revealSkipped: [...d.revealSkipped, engineId]));
  }

  /// The MJ says which wolf the dead Knight's sword left diseased (null: none). The setting says
  /// whether it dies as the next night begins or ends.
  Future<void> knightContaminate(String? wolfEngineId) => applyAction(
    KnightContaminate(
      wolfPlayerId: wolfEngineId,
      atNightEnd: ref.read(settingsProvider).value?.knightDiseaseAtNightEnd ?? false,
    ),
  );

  Future<void> hunterShoot(String? engineId) =>
      applyAction(HunterShoot(targetPlayerId: engineId));

  /// The Village Idiot's honor is lost with him: no successor.
  Future<void> captainHasNoSuccessor() => applyAction(const CaptainNoSuccessor());

  Future<void> nameCaptainSuccessor(String engineId) =>
      applyAction(CaptainNameSuccessor(successorPlayerId: engineId));

  Future<void> acknowledgeLoversDeaths() =>
      _updateDay((d) => d.copyWith(loversAck: const []));

  // --- day -> next night ---

  Future<void> startNextNight() async {
    final s = state.value;
    if (s == null) return;
    final result = _machine.apply(
      state: s.engine,
      action: const StartNextNight(),
      roleRegistry: _registry,
    );
    final lines = nightLogEntriesForEvents(
      result.events,
      result.state,
      phase: JournalPhase.night,
    );
    if (lines.isNotEmpty) {
      await ref.read(gameRepositoryProvider).appendNightLog(gameId: gameId, entries: lines);
    }
    const cursor = SessionCursor.nightStart;
    const day = DaySnapshot.fresh;
    await _persist(result.state, cursor, day);
    _emit(s, engine: result.state, cursor: cursor, day: day);
  }

  // --- the engine-action pipeline ---

  /// Report an MJ fact to the engine, journal what it produced, fold any
  /// day-state change in, and persist.
  Future<void> applyAction(GameAction action) async {
    final s = state.value;
    if (s == null) return;
    final result = _machine.apply(state: s.engine, action: action, roleRegistry: _registry);

    final lines = <NightLogEntry>[
      ...nightLogEntriesFor(action, s.engine),
      ...nightLogEntriesForEvents(
        result.events,
        result.state,
        phase: _journalPhase(result.state),
      ),
      for (final e in result.events)
        if (e is PlayerDied && e.cause is LoversCascadeKill)
          NightLogEntry(
            phase: _journalPhase(result.state),
            phaseIndex: result.state.nightIndex,
            kind: JournalKind.heartbreakDeath,
            args: {'player': s.engine.playerById(e.playerId).name},
          ),
    ];
    if (lines.isNotEmpty) {
      await ref.read(gameRepositoryProvider).appendNightLog(gameId: gameId, entries: lines);
    }

    final cursor = _cursorAfter(action, s.cursor);
    final day = _dayAfter(action, result, s);
    // RevealRole and a Voleur swap both write a role onto the roster first.
    final roster = action is RevealRole || action is VoleurSwap
        ? await _loadRoster()
        : s.roster;

    await _persist(result.state, cursor, day);
    _emit(s, engine: result.state, cursor: cursor, day: day, roster: roster);
  }

  DaySnapshot _dayAfter(GameAction action, ActionResult result, GameSessionState s) {
    var day = s.day;

    final victimId = s.engine.pendingWolfVictimId;
    if (action is WitchLifePotion && victimId != null) {
      day = day.copyWith(savedFromWolvesName: s.engine.playerById(victimId).name);
    }

    final griefDeaths = [
      for (final e in result.events)
        if (e is PlayerDied && e.cause is LoversCascadeKill) e.playerId,
    ];
    if (griefDeaths.isNotEmpty) {
      day = day.copyWith(loversAck: [...day.loversAck, ...griefDeaths]);
    }

    if (action is ElectCaptain) {
      day = day.copyWith(stage: nextDayStage(DayStage.captain, result.state));
    }
    if (action is DayVoteTie) {
      day = day.copyWith(stage: nextDayStage(DayStage.vote, result.state));
    }
    if (action is DayVoteElimination) {
      day = day.copyWith(stage: nextDayStage(DayStage.vote, result.state));
      for (final e in result.events) {
        if (e is IdiotPardoned) {
          day = day.copyWith(pardonedName: result.state.playerById(e.playerId).name);
        }
      }
    }

    return day;
  }

  SessionCursor _cursorAfter(GameAction action, SessionCursor c) => switch (action) {
    // These complete a night role's turn -> advance to the next step.
    WolvesTarget() ||
    CupidonPair() ||
    VoleurSwap() ||
    FoxSniff() ||
    WildChildChooseModel() ||
    ChienLoupChoose() ||
    InfectVictim() ||
    BigBadWolfTarget() ||
    WhiteWolfEat() ||
    PiperCharm() ||
    DefenderProtect() => SessionCursor(
      stepIndex: c.stepIndex + 1,
      subStep: NightSubStep.identify,
    ),
    // The Witch's turn spans several taps, FinalizeNight flips the phase, and
    // every day action leaves the night cursor untouched.
    _ => c,
  };

  Future<void> _updateDay(DaySnapshot Function(DaySnapshot) f) async {
    final s = state.value;
    if (s == null) return;
    final day = f(s.day);
    await _persist(s.engine, s.cursor, day);
    _emit(s, day: day);
  }

  void _emit(
    GameSessionState prev, {
    GameState? engine,
    SessionCursor? cursor,
    DaySnapshot? day,
    List<PlayerRow>? roster,
    List<String>? reserveRoleIds,
  }) {
    final nextEngine = engine ?? prev.engine;
    final nextReserve = reserveRoleIds ?? prev.reserveRoleIds;
    state = AsyncData(
      GameSessionState(
        engine: nextEngine,
        cursor: cursor ?? prev.cursor,
        day: day ?? prev.day,
        tonight: buildNightScript(
          engine: nextEngine,
          composition: prev.composition,
          dealtComposition: dealtCompositionOf(
            prev.composition,
            nextReserve,
            reserveDrawn: prev.reserveDrawn,
          ),
          foxAfterWitch: prev.foxAfterWitch,
          whiteWolfOddNights: prev.whiteWolfOddNights,
        ),
        composition: prev.composition,
        reserveRoleIds: nextReserve,
        reserveDrawn: prev.reserveDrawn,
        foxAfterWitch: prev.foxAfterWitch,
        whiteWolfOddNights: prev.whiteWolfOddNights,
        roster: roster ?? prev.roster,
        voleurSwapIn: _voleurSwapIn,
      ),
    );
  }
}
