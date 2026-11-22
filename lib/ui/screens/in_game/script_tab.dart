import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../../data/models/game_winner.dart';
import '../../../state/session/day_plan.dart';
import '../../../state/session/game_session.dart';
import '../../../state/session/night_script.dart' show kCharmedStepRole;
import '../../../state/session/session_cursor.dart';
import '../../../state/settings/settings.dart' show VoteTieRule;
import '../../../state/settings/settings_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../utils/l10n.dart';
import '../../utils/narration.dart';
import '../../widgets/app_button.dart';
import '../../widgets/narration_block.dart';
import '../../widgets/avatar_pick_cell.dart';
import '../../widgets/player_avatar.dart';
import 'widgets/elder_question.dart';
import 'widgets/fox_act.dart';
import 'widgets/identify_step.dart';
import 'widgets/two_choice_act.dart';
import 'widgets/reserve_entry.dart';
import 'widgets/simple_act.dart';
import 'widgets/target_pick.dart';
import 'widgets/unreadable_game_notice.dart';
import 'widgets/witch_act.dart';
import '../../utils/labels.dart';

/// The Script tab: the current step of the loop. Night -> the wake script;
/// day -> the recap. (The per-step bodies land in the next commits.)
class ScriptTab extends ConsumerWidget {
  const ScriptTab({required this.gameId, super.key});

  final int gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(gameSessionProvider(gameId));

    return sessionAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => UnreadableGameNotice(
        gameId: gameId,
        message: context.l10n.scriptLoadError,
      ),
      data: (session) => session.engine.phase == GamePhase.night
          ? _NightBody(gameId: gameId, session: session)
          : _DayBody(gameId: gameId, session: session),
    );
  }
}

class _NightBody extends ConsumerWidget {
  const _NightBody({required this.gameId, required this.session});

  final int gameId;
  final GameSessionState session;

  List<String> _holderNames(String roleId) => [
    for (final p in session.engine.players)
      if (roleId == kCharmedStepRole.id
          ? p.alive && p.hasStatus(PlayerStatus.charmed)
          : p.roleId == roleId)
        p.name,
  ];

  /// Where tonight's first real call is: the steps before it are settled before the village
  /// sleeps.
  int get _firstCallIndex => session.tonight.steps.indexWhere((s) => !s.role.preparation);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(gameSessionProvider(gameId).notifier);
    final step = session.currentStep;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NightHeader(
          nightIndex: session.engine.nightIndex,
          stepCount: session.tonight.steps.length,
          currentStep: session.cursor.stepIndex,
          showDots: session.engine.nightIndex == 1,
        ),
        if (step != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 0),
            child: Column(
              spacing: 8,
              children: [
                _ScriptCard(
                  role: step.role,
                  holderNames: session.currentStepNeedsIdentify
                      ? const []
                      : _holderNames(step.role.id),
                ),
                NarrationBlock(
                  lines: [
                    // the first call of the night is preceded by "the village goes to sleep"; what is
                    // settled before that (a card shown at the deal) comes ahead of it
                    if (session.cursor.stepIndex == _firstCallIndex) ...nightStartNarration(context.l10n),
                    ...roleCallNarration(context.l10n, step.role.id),
                  ],
                ),
              ],
            ),
          ),
        Expanded(child: _body(context, notifier, step)),
      ],
    );
  }

  /// The Elder has no call of his own, so the app learns he is one when the wolves pick him: asks,
  /// and notes the card, so his first bite is spared.
  Future<void> _askIfElder(BuildContext context, GameSession notifier, String victimId) async {
    if (!session.mayBeElder(victimId)) return;
    final name = session.engine.playerById(victimId).name;
    final isElder = await showElderQuestion(context, name: name);
    if (isElder == true) await notifier.identifyRole('ancien', [int.parse(victimId)]);
  }

  Widget _body(BuildContext context, GameSession notifier, NightScriptStep? step) {
    if (session.engine.cascade != null) {
      return _ChainPanel(session: session, notifier: notifier);
    }
    if (step == null) {
      return _FinalizePrompt(onResolve: () => notifier.applyAction(const FinalizeNight()));
    }
    if (step.role.id == 'voleur' &&
        session.reserveToEnter &&
        session.cursor.subStep != NightSubStep.act) {
      return ReserveEntry(
        pack: session.pack,
        onConfirm: notifier.enterReserve,
        onDefer: notifier.skipStep,
      );
    }
    if (session.currentStepNeedsIdentify) {
      final roleId = step.role.id;
      // Holders already on record (the Voyante noted one, the Voleur stole the
      // card) show pre-selected and locked; the count only asks for the dealt
      // cards still missing - and never counts the Voleur's bonus card.
      final locked = [
        for (final p in session.engine.alivePlayers)
          if (p.roleId == roleId) p,
      ];
      final voleurAmongLocked = session.voleurSwapIn?.roleId == roleId &&
          locked.any((p) => p.id == session.voleurSwapIn!.playerId);
      final taken = {
        for (final r in session.roster)
          if (r.roleId != null) r.id,
      };
      return IdentifyStep(
        role: step.role,
        count: session.expectedHolders(roleId) - session.dealtHoldersKnown(roleId),
        candidates: [
          for (final p in session.engine.alivePlayers)
            if (!taken.contains(int.parse(p.id))) (rowId: int.parse(p.id), name: p.name),
        ],
        locked: [for (final p in locked) (rowId: int.parse(p.id), name: p.name)],
        lockedNote: locked.isEmpty
            ? null
            : voleurAmongLocked
            ? context.l10n.scriptThiefExtra(context.l10n.roleName(step.role.id))
            : context.l10n.scriptSeerKnown,
        onConfirm: (rowIds) => notifier.identifyRole(roleId, rowIds),
        onDefer: notifier.skipStep,
      );
    }
    return _actBody(context, notifier, step);
  }

  Widget _actBody(BuildContext context, GameSession notifier, NightScriptStep step) {
    final role = step.role;
    final alive = session.engine.alivePlayers;
    Candidate cand(Player p) => (id: p.id, name: p.name);

    // Every card of this role is in the Voleur's reserve: nobody holds it, but the MJ still
    // calls it so the table cannot tell. Nothing to act.
    if (session.reserveDrawn &&
        session.reserveRoleIds.isNotEmpty &&
        !alive.any((p) => p.roleId == role.id) &&
        session.expectedHolders(role.id) == 0 &&
        role.id != 'voleur') {
      return SimpleAct(primaryLabel: context.l10n.scriptSkipRole, onPrimary: notifier.skipStep);
    }

    switch (role.id) {
      case 'voyante':
        final rosterRole = {for (final r in session.roster) r.id: r.roleId};
        return _SeerAct(
          // The card says "un autre joueur" - she can't look at herself.
          targets: [
            for (final p in alive)
              if (p.roleId != 'voyante')
                (
                  rowId: int.parse(p.id),
                  name: p.name,
                  knownRoleId: rosterRole[int.parse(p.id)],
                ),
          ],
          noteOptions: unassignedRoles(session),
          onInspect: (rowId, notedRoleId) =>
              notifier.seerInspect(targetRowId: rowId, notedRoleId: notedRoleId),
          onSkip: notifier.skipStep,
        );

      case 'renard':
        return FoxAct(
          candidates: [for (final p in alive) cand(p)],
          trioFor: (middleId) => [
            for (final p in session.engine.foxTrio(middleId)) p.name,
          ],
          appKnowsWolf: (middleId) => session.engine.wolfAmong(
            session.engine.foxTrio(middleId),
            RoleRegistry.all,
          ),
          onAnswer: (middleId, wolfFound) =>
              notifier.foxSniff(middleEngineId: middleId, wolfFound: wolfFound),
          onSkip: notifier.skipStep,
        );

      case 'enfant_sauvage':
        final child = session.engine.players.where((p) => p.alive && p.roleId == role.id).firstOrNull;
        if (child == null) {
          return SimpleAct(primaryLabel: context.l10n.scriptSkipRole, onPrimary: notifier.skipStep);
        }
        return TargetPick(
          question: context.l10n.scriptWildChildQuestion,
          candidates: [for (final p in alive) if (p.id != child.id) cand(p)],
          confirmLabel: context.l10n.scriptWildChildModel,
          onConfirm: (id) => notifier.wildChildChoose(childEngineId: child.id, modelEngineId: id),
          secondaryLabel: context.l10n.scriptSkipRole,
          onSecondary: notifier.skipStep,
        );

      case 'chien_loup':
        final dog = session.engine.players.where((p) => p.alive && p.roleId == role.id).firstOrNull;
        if (dog == null) {
          return SimpleAct(primaryLabel: context.l10n.scriptSkipRole, onPrimary: notifier.skipStep);
        }
        return TwoChoiceAct(
          question: context.l10n.scriptChienLoupQuestion,
          firstLabel: context.l10n.scriptChienLoupWolf,
          onFirst: () => notifier.chienLoupChoose(engineId: dog.id, wolf: true),
          secondLabel: context.l10n.scriptChienLoupVillager,
          onSecond: () => notifier.chienLoupChoose(engineId: dog.id, wolf: false),
        );

      case 'infect_pere_des_loups':
        final victimId = session.engine.pendingWolfVictimId;
        if (victimId == null) {
          return SimpleAct(
            primaryLabel: context.l10n.commonContinue,
            onPrimary: notifier.skipStep,
          );
        }
        final victim = session.engine.playerById(victimId).name;
        return TwoChoiceAct(
          question: context.l10n.scriptInfectAsk(victim),
          firstLabel: context.l10n.scriptInfectNo,
          onFirst: notifier.skipStep,
          secondLabel: context.l10n.scriptInfectYes(victim),
          onSecond: notifier.infectVictim,
        );

      case 'grand_mechant_loup':
        return TargetPick(
          question: context.l10n.scriptBigBadWolfQuestion,
          candidates: [
            for (final p in alive)
              if (!session.engine.wakesWithWolves(p, RoleRegistry.all) &&
                  p.id != session.engine.pendingWolfVictimId)
                cand(p),
          ],
          confirmLabel: context.l10n.scriptBigBadWolfPick,
          onConfirm: (id) async {
            await _askIfElder(context, notifier, id);
            await notifier.bigBadWolfTarget(id);
          },
          secondaryLabel: context.l10n.scriptSkipRole,
          onSecondary: notifier.skipStep,
        );

      case 'loup_garou_blanc':
        // The first night he only wakes with the wolves: nothing to act, just to be known.
        if (step.identifyOnly) {
          return SimpleAct(
            primaryLabel: context.l10n.commonContinue,
            onPrimary: notifier.skipStep,
          );
        }
        return TargetPick(
          question: context.l10n.scriptWhiteWolfQuestion,
          candidates: [
            for (final p in alive)
              if (session.engine.wakesWithWolves(p, RoleRegistry.all) && p.roleId != role.id)
                cand(p),
          ],
          confirmLabel: context.l10n.scriptWhiteWolfPick,
          onConfirm: notifier.whiteWolfEat,
          secondaryLabel: context.l10n.scriptSkipRole,
          onSecondary: notifier.skipStep,
        );

      case 'deux_soeurs':
        return SimpleAct(
          primaryLabel: context.l10n.scriptSistersDone,
          onPrimary: notifier.sistersMet,
          secondaryLabel: context.l10n.scriptSkipRole,
          onSecondary: notifier.skipStep,
        );

      case 'trois_freres':
        return SimpleAct(
          primaryLabel: context.l10n.scriptBrothersDone,
          onPrimary: notifier.brothersMet,
          secondaryLabel: context.l10n.scriptSkipRole,
          onSecondary: notifier.skipStep,
        );

      case 'abominable_sectaire':
        // The village is divided before the night; he has no call of his own.
        return _DivideAct(
          candidates: [for (final p in session.engine.players) cand(p)],
          onConfirm: notifier.divideVillage,
          onSkip: notifier.skipStep,
        );

      case 'juge_begue':
        // He only shows the MJ his secret sign; the second vote it calls for plays in the day.
        return SimpleAct(
          primaryLabel: context.l10n.commonContinue,
          onPrimary: notifier.skipStep,
        );

      case 'villageois_villageois':
        // His card is public: the MJ only notes who shows it.
        return SimpleAct(
          primaryLabel: context.l10n.commonContinue,
          onPrimary: notifier.skipStep,
        );

      case 'montreur_d_ours':
        // He only makes himself known tonight; his power plays in the morning.
        return SimpleAct(
          primaryLabel: context.l10n.commonContinue,
          onPrimary: notifier.skipStep,
        );

      case 'cupidon':
        return _LoversPick(
          candidates: [for (final p in alive) cand(p)],
          onConfirm: (a, b) => notifier.pairLovers(a, b),
          onSkip: notifier.skipStep,
          question: context.l10n.scriptLoversQuestion,
          pairLabel: context.l10n.scriptLoversPair,
          pickLabel: context.l10n.scriptLoversPick,
          icon: AppIcons.cupid,
        );

      case 'joueur_de_flute':
        return _LoversPick(
          candidates: [
            for (final p in alive)
              if (p.roleId != role.id && !p.hasStatus(PlayerStatus.charmed)) cand(p),
          ],
          onConfirm: (a, b) => notifier.piperCharm([a, b]),
          onSkip: notifier.skipStep,
          question: context.l10n.scriptPiperQuestion,
          pairLabel: context.l10n.scriptPiperCharm,
          pickLabel: context.l10n.scriptLoversPick,
          icon: AppIcons.piperRole,
          single: (
            label: context.l10n.scriptPiperCharmOne,
            onConfirm: (id) => notifier.piperCharm([id]),
          ),
        );

      case 'joueurs_charmes':
        return SimpleAct(
          primaryLabel: context.l10n.scriptCharmedDone,
          onPrimary: notifier.skipStep,
        );

      case 'loup_garou':
        return TargetPick(
          question: context.l10n.scriptWolvesQuestion,
          candidates: [
            for (final p in alive)
              if (!session.engine.wakesWithWolves(p, RoleRegistry.all)) cand(p),
          ],
          confirmLabel: context.l10n.scriptWolvesPick,
          onConfirm: (id) async {
            await _askIfElder(context, notifier, id);
            await notifier.applyAction(WolvesTarget(targetPlayerId: id));
          },
          secondaryLabel: context.l10n.scriptSkipRole,
          onSecondary: notifier.skipStep,
        );

      case 'salvateur':
        return TargetPick(
          question: context.l10n.scriptDefenderQuestion,
          candidates: [
            for (final p in alive)
              if (p.id != session.engine.defenderLastProtectedId) cand(p),
          ],
          confirmLabel: context.l10n.scriptDefenderProtects,
          onConfirm: notifier.defenderProtect,
          secondaryLabel: context.l10n.scriptSkipRole,
          onSecondary: notifier.skipStep,
        );

      case 'sorciere':
        final victimId = session.engine.wolfVictimForWitch;
        return WitchAct(
          witch: session.engine.witch,
          wolfVictim: victimId == null ? null : cand(session.engine.playerById(victimId)),
          candidates: [for (final p in alive) cand(p)],
          onSave: () => notifier.applyAction(const WitchLifePotion()),
          onPoison: (id) => notifier.applyAction(WitchDeathPotion(targetPlayerId: id)),
          onDone: notifier.skipStep,
        );

      case 'voleur':
        final voleur = session.engine.players.where((p) => p.roleId == 'voleur').firstOrNull;
        if (voleur == null || session.reserveRoleIds.isEmpty) {
          return SimpleAct(primaryLabel: context.l10n.scriptSkipRole, onPrimary: notifier.skipStep);
        }
        return _VoleurAct(
          reserveRoleIds: session.reserveRoleIds,
          mustSwap: session.reserveForcesSwap,
          onConfirm: (stolenRoleId) => notifier.voleurSwap(
            voleurEngineId: voleur.id,
            stolenRoleId: stolenRoleId,
          ),
        );

      default:
        return SimpleAct(primaryLabel: context.l10n.scriptSkipRole, onPrimary: notifier.skipStep);
    }
  }
}

/// The Voleur's turn: swap his card for one of the two reserve cards, or keep
/// his own. The two reserve cards double as the reminder of what's on the
/// table - no separate collapsible needed. A stolen night role gets a nudge.
class _VoleurAct extends StatefulWidget {
  const _VoleurAct({
    required this.reserveRoleIds,
    required this.onConfirm,
    this.mustSwap = false,
  });

  final List<String> reserveRoleIds;

  /// Both reserve cards are wolves: he cannot keep his own card.
  final bool mustSwap;

  /// null = he keeps his card.
  final void Function(String? stolenRoleId) onConfirm;

  @override
  State<_VoleurAct> createState() => _VoleurActState();
}

class _VoleurActState extends State<_VoleurAct> {
  /// '' once "keep" is chosen, a role id once a reserve card is, null while
  /// nothing is picked.
  String? _choice;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final picked = _choice != null;
    final keeps = _choice == '';
    final stolen = keeps ? null : _choice;
    final stolenRole = stolen == null ? null : RoleRegistry.all.byId(stolen);
    final stealsNightRole = (stolenRole?.hasNightCall ?? false) && !stolenRole!.preparation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 18, AppSpacing.screen, 8),
          child: Text(
            context.l10n.scriptThiefReserve,
            style: typography.rowLabel.copyWith(color: colors.textPrimary),
          ),
        ),
        if (widget.mustSwap)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 8),
            child: Text(
              context.l10n.scriptThiefMustSwap,
              style: typography.meta.copyWith(color: colors.warnText, height: 1.5),
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            children: [
              for (final id in widget.reserveRoleIds)
                _RoleOption(
                  roleId: id,
                  remaining: 1,
                  selected: _choice == id,
                  onTap: () => setState(() => _choice = id),
                ),
              if (!widget.mustSwap)
                _KeepCardOption(
                  selected: keeps,
                  onTap: () => setState(() => _choice = ''),
                ),
            ],
          ),
        ),
        if (stealsNightRole)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 8),
            child: Text(
              context.l10n.scriptThiefBecomes(context.l10n.roleWithArticle(stolen!)),
              style: typography.meta.copyWith(color: colors.warnText, height: 1.5),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            4,
            AppSpacing.screen,
            AppSpacing.screen,
          ),
          child: AppButton(
            label: !picked
                ? context.l10n.scriptPickCard
                : keeps
                ? context.l10n.scriptThiefKeeps
                : context.l10n.scriptThiefTakes(context.l10n.roleWithArticle(stolen!)),
            onPressed: !picked ? null : () => widget.onConfirm(stolen),
          ),
        ),
      ],
    );
  }
}

class _KeepCardOption extends StatelessWidget {
  const _KeepCardOption({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? colors.accentBg : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.button),
          border: Border.all(color: selected ? colors.accentBorder : colors.borderControl),
        ),
        child: Row(
          spacing: 12,
          children: [
            Icon(
              AppIcons.thief,
              size: 18,
              color: selected ? colors.accentText : colors.textSecondary,
            ),
            Expanded(
              child: Text(
                context.l10n.scriptThiefKeepOption,
                style: typography.rowLabel.copyWith(
                  color: selected ? colors.accentText : colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef _SeerTarget = ({int rowId, String name, String? knownRoleId});

/// The Voyante's turn: pick a player, then see their card. If the card is
/// already on record it shows straight away; otherwise the MJ notes it (a
/// third way the app learns a role). The reveal is an inline `accent/bg`
/// panel, then "Continuer" advances - the peek changes no game state.
class _SeerAct extends StatefulWidget {
  const _SeerAct({
    required this.targets,
    required this.noteOptions,
    required this.onInspect,
    required this.onSkip,
  });

  final List<_SeerTarget> targets;
  final List<({String roleId, int remaining})> noteOptions;

  /// (targetRowId, notedRoleId) - notedRoleId is null when the card was
  /// already known.
  final void Function(int targetRowId, String? notedRoleId) onInspect;
  final VoidCallback onSkip;

  @override
  State<_SeerAct> createState() => _SeerActState();
}

enum _SeerPhase { pickTarget, noteCard, result }

class _SeerActState extends State<_SeerAct> {
  _SeerPhase _phase = _SeerPhase.pickTarget;
  _SeerTarget? _target;
  String? _noted;

  String? get _cardRoleId => _target?.knownRoleId ?? _noted;

  void _onTargetPicked(String rowIdStr) {
    final t = widget.targets.firstWhere((c) => c.rowId == int.parse(rowIdStr));
    setState(() {
      _target = t;
      _phase = t.knownRoleId != null ? _SeerPhase.result : _SeerPhase.noteCard;
    });
  }

  @override
  Widget build(BuildContext context) {
    return switch (_phase) {
      _SeerPhase.pickTarget => TargetPick(
        question: context.l10n.scriptSeerQuestion,
        candidates: [for (final t in widget.targets) (id: '${t.rowId}', name: t.name)],
        confirmLabel: context.l10n.scriptSeerPick,
        onConfirm: _onTargetPicked,
        secondaryLabel: context.l10n.scriptSkipRole,
        onSecondary: widget.onSkip,
      ),
      _SeerPhase.noteCard => _SeerNote(
        name: _target!.name,
        options: widget.noteOptions,
        onConfirm: (roleId) => setState(() {
          _noted = roleId;
          _phase = _SeerPhase.result;
        }),
      ),
      _SeerPhase.result => _SeerResult(
        name: _target!.name,
        roleId: _cardRoleId!,
        onContinue: () => widget.onInspect(_target!.rowId, _noted),
      ),
    };
  }
}

class _SeerNote extends StatefulWidget {
  const _SeerNote({required this.name, required this.options, required this.onConfirm});

  final String name;
  final List<({String roleId, int remaining})> options;
  final ValueChanged<String> onConfirm;

  @override
  State<_SeerNote> createState() => _SeerNoteState();
}

class _SeerNoteState extends State<_SeerNote> {
  String? _roleId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 18, AppSpacing.screen, 4),
          child: Text(
            context.l10n.scriptSeerNote,
            style: typography.meta.copyWith(color: colors.textSecondary, height: 1.5),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 12, AppSpacing.screen, 8),
          child: Text(
            context.l10n.scriptCardOf(widget.name),
            style: typography.meta.copyWith(color: colors.textTertiary),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            children: [
              for (final o in widget.options)
                _RoleOption(
                  roleId: o.roleId,
                  remaining: o.remaining,
                  selected: o.roleId == _roleId,
                  onTap: () => setState(() => _roleId = o.roleId),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            12,
            AppSpacing.screen,
            AppSpacing.screen,
          ),
          child: AppButton(
            label: _roleId == null
                ? context.l10n.scriptPickCard
                : context.l10n.scriptNameIs(widget.name, context.l10n.roleWithArticle(_roleId!)),
            onPressed: _roleId == null ? null : () => widget.onConfirm(_roleId!),
          ),
        ),
      ],
    );
  }
}

class _SeerResult extends StatelessWidget {
  const _SeerResult({required this.name, required this.roleId, required this.onContinue});

  final String name;
  final String roleId;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final role = RoleRegistry.all.byId(roleId);
    final wolves = role.team == Team.werewolves;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 18, AppSpacing.screen, 0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.accentBg,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.scriptSeerSees,
                  style: typography.counter.copyWith(color: colors.accentText),
                ),
                const SizedBox(height: 8),
                Row(
                  spacing: 12,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colors.bgScreen,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_roleIcon(roleId), size: 18, color: colors.accentText),
                    ),
                    Expanded(
                      child: Text(
                        context.l10n.scriptNameIs(name, context.l10n.roleWithArticle(roleId)),
                        style: typography.rowLabel.copyWith(
                          fontSize: 16,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.bgScreen,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Text(
                        wolves ? context.l10n.compositionWolves : context.l10n.compositionVillage,
                        style: typography.counter.copyWith(color: colors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            0,
            AppSpacing.screen,
            AppSpacing.screen,
          ),
          child: AppButton(label: context.l10n.commonContinue, onPressed: onContinue),
        ),
      ],
    );
  }
}

/// Cupidon's turn: pick exactly two players to fall in love. Night 1 only. The
/// button names both, per the design.
class _LoversPick extends StatefulWidget {
  const _LoversPick({
    required this.candidates,
    required this.onConfirm,
    required this.onSkip,
    required this.question,
    required this.pairLabel,
    required this.pickLabel,
    required this.icon,
    this.single,
  });

  final List<Candidate> candidates;
  final void Function(String a, String b) onConfirm;
  final VoidCallback onSkip;
  final String question;

  /// The button once two are picked: "Cupidon unit A et B".
  final String Function(String a, String b) pairLabel;
  final String pickLabel;
  final IconData icon;

  /// With a single player left to pick, the button and what it does (the Piper may charm just one).
  final ({String Function(String name) label, void Function(String id) onConfirm})? single;

  @override
  State<_LoversPick> createState() => _LoversPickState();
}

class _LoversPickState extends State<_LoversPick> {
  final _selected = <String>[];

  void _toggle(String id) {
    setState(() {
      if (_selected.remove(id)) return;
      if (_selected.length < 2) _selected.add(id);
      // at capacity: refuse the extra (deselect one to change it)
    });
  }

  String _name(String id) => widget.candidates.firstWhere((c) => c.id == id).name;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    // Two to pick, or the one that is left when only one can be (the Piper's last charm).
    final needed = widget.candidates.length == 1 && widget.single != null ? 1 : 2;
    final complete = _selected.length == needed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 18, AppSpacing.screen, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.question,
                  style: typography.rowLabel.copyWith(color: colors.textPrimary),
                ),
              ),
              Text(
                context.l10n.identifyProgress(_selected.length, needed),
                style: typography.counter.copyWith(color: colors.accentText),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.count(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            crossAxisCount: AppSizes.gridColumnsDefault,
            mainAxisSpacing: AppSpacing.gridGapRow,
            crossAxisSpacing: AppSpacing.gridGapColumn,
            childAspectRatio: 1.0,
            children: [
              for (final c in widget.candidates)
                AvatarPickCell(
                  name: c.name,
                  selected: _selected.contains(c.id),
                  onTap: () => _toggle(c.id),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            12,
            AppSpacing.screen,
            AppSpacing.screen,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              AppButton(
                label: !complete
                    ? widget.pickLabel
                    : needed == 1
                    ? widget.single!.label(_name(_selected[0]))
                    : widget.pairLabel(_name(_selected[0]), _name(_selected[1])),
                leadingIcon: complete ? widget.icon : null,
                onPressed: !complete
                    ? null
                    : needed == 1
                    ? () => widget.single!.onConfirm(_selected[0])
                    : () => widget.onConfirm(_selected[0], _selected[1]),
              ),
              AppButton(
                label: context.l10n.scriptSkipRole,
                variant: AppButtonVariant.secondary,
                onPressed: widget.onSkip,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FinalizePrompt extends StatelessWidget {
  const _FinalizePrompt({required this.onResolve});

  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 10),
          child: Text(
            context.l10n.scriptAllPlayed,
            style: context.typography.body.copyWith(color: colors.textSecondary),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            0,
            AppSpacing.screen,
            AppSpacing.screen,
          ),
          child: AppButton(label: context.l10n.scriptResolveNight, onPressed: onResolve),
        ),
      ],
    );
  }
}

/// The night phase eyebrow, under the persistent shell header. Night 1 also
/// carries the step-progress dots on the right.
class _NightHeader extends StatelessWidget {
  const _NightHeader({
    required this.nightIndex,
    required this.stepCount,
    required this.currentStep,
    required this.showDots,
  });

  final int nightIndex;
  final int stepCount;
  final int currentStep;
  final bool showDots;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _PhaseEyebrow(icon: AppIcons.night, label: context.l10n.summaryPhase('night', nightIndex)),
          if (showDots)
            Row(
              spacing: 5,
              children: [
                for (var i = 0; i < stepCount; i++)
                  _Dot(
                    state: i < currentStep
                        ? _DotState.past
                        : i == currentStep
                        ? _DotState.current
                        : _DotState.future,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// `moon`/`sun` at 14 + an uppercase 0.06em label - the phase line, demoted to
/// an eyebrow now that the shell header carries the game's identity.
class _PhaseEyebrow extends StatelessWidget {
  const _PhaseEyebrow({required this.icon, required this.label, this.iconColor});

  final IconData icon;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 7,
      children: [
        Icon(icon, size: 14, color: iconColor ?? colors.textSecondary),
        Text(
          label.toUpperCase(),
          style: context.typography.sectionLabel.copyWith(color: colors.textTertiary),
        ),
      ],
    );
  }
}

enum _DotState { past, current, future }

class _Dot extends StatelessWidget {
  const _Dot({required this.state});

  final _DotState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return switch (state) {
      _DotState.current => Container(
        width: 16,
        height: 5,
        decoration: BoxDecoration(
          color: colors.accentBorder,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      _DotState.past => Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(color: colors.textTertiary, shape: BoxShape.circle),
      ),
      _DotState.future => Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(color: colors.borderHairline, shape: BoxShape.circle),
      ),
    };
  }
}

class _ScriptCard extends StatelessWidget {
  const _ScriptCard({required this.role, this.holderNames = const []});

  final Role role;

  /// The identified holder name(s), shown under the role name once known.
  final List<String> holderNames;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.bgInset,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            spacing: 10,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: colors.accentBg, shape: BoxShape.circle),
                child: Icon(_roleIcon(role.id), size: 17, color: colors.accentText),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.roleName(role.id),
                      style: typography.rowLabel.copyWith(
                        fontSize: 16,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (holderNames.isNotEmpty)
                      Text(
                        holderNames.join(', '),
                        style: typography.counter.copyWith(color: colors.textTertiary),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.roleRuleText(role.id),
            style: typography.body.copyWith(color: colors.textSecondary, height: 1.6),
          ),
        ],
      ),
    );
  }
}

IconData _roleIcon(String roleId) => switch (roleId) {
  'loup_garou' => AppIcons.wolves,
  'voyante' => AppIcons.seer,
  'sorciere' => AppIcons.witch,
  'cupidon' => AppIcons.cupid,
  'voleur' => AppIcons.thief,
  'chasseur' => AppIcons.hunter,
  'ancien' => AppIcons.elder,
  'bouc_emissaire' => AppIcons.scapegoat,
  'idiot_du_village' => AppIcons.idiot,
  'salvateur' => AppIcons.defender,
  'ange' => AppIcons.angel,
  'chevalier' => AppIcons.knight,
  'joueur_de_flute' => AppIcons.piperRole,
  'joueurs_charmes' => AppIcons.piperRole,
  'renard' => AppIcons.fox,
  'deux_soeurs' => AppIcons.sisters,
  'trois_freres' => AppIcons.brothers,
  'villageois_villageois' => AppIcons.trustedVillager,
  'juge_begue' => AppIcons.judge,
  'abominable_sectaire' => AppIcons.sectarian,
  'montreur_d_ours' => AppIcons.bearTamer,
  'enfant_sauvage' => AppIcons.wildChild,
  'chien_loup' => AppIcons.chienLoup,
  'loup_garou_blanc' => AppIcons.whiteWolf,
  'infect_pere_des_loups' => AppIcons.infect,
  'grand_mechant_loup' => AppIcons.bigBadWolf,
  'capitaine' => AppIcons.captain,
  _ => AppIcons.village,
};

/// The day side of the Script tab. An interrupt (a card to reveal, a chain
/// effect, a lover's grief death) takes over the body until it's cleared;
/// otherwise the current [DayStage] shows.
class _DayBody extends ConsumerWidget {
  const _DayBody({required this.gameId, required this.session});

  final int gameId;
  final GameSessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(gameSessionProvider(gameId).notifier);

    switch (session.dayInterrupt) {
      case DayInterrupt.reveal:
        return _RevealPanel(session: session, notifier: n);
      case DayInterrupt.chain:
        return _ChainPanel(session: session, notifier: n);
      case DayInterrupt.loversAck:
        return _LoversAckPanel(session: session, notifier: n);
      case null:
        break;
    }

    final body = switch (session.day.stage) {
      DayStage.recap => _DayRecapBody(session: session, onAdvance: n.advanceFromRecap),
      DayStage.growl => _BearGrowlBody(session: session, notifier: n),
      DayStage.captain => _CaptainElectionBody(session: session, notifier: n),
      DayStage.vote || DayStage.secondVote => _VoteBody(
        key: ValueKey(session.day.stage),
        session: session,
        notifier: n,
      ),
      DayStage.done => _NextNightPrompt(
        nextNight: session.engine.nightIndex + 1,
        onStart: n.startNextNight,
        note: session.day.pardonedName == null
            ? null
            : context.l10n.scriptIdiotPardoned(session.day.pardonedName!),
      ),
    };
    final proposed = session.proposedWinner;
    final powerless = session.engine.villagersPowerless;
    final beforeNight1 = session.engine.nightIndex == 0;
    if (proposed == null && !powerless && !beforeNight1) return body;
    return Column(
      children: [
        if (beforeNight1) const _AngelDebateBanner(),
        if (proposed != null)
          _VictoryProposalBanner(
            winner: proposed,
            onEnd: () => context.push('/games/$gameId/end'),
          ),
        if (powerless) const _PowerlessBanner(),
        Expanded(child: body),
      ],
    );
  }
}

/// The game starts with a debate and a vote: the Angel is in play.
class _AngelDebateBanner extends StatelessWidget {
  const _AngelDebateBanner();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.screen, 8, AppSpacing.screen, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.accentBg,
        borderRadius: BorderRadius.circular(AppRadii.button),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Icon(AppIcons.angel, size: 18, color: colors.accentText),
          Expanded(
            child: Text(
              context.l10n.scriptAngelDebate,
              style: context.typography.meta.copyWith(color: colors.accentText, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// A reminder that the villagers lost their powers: the script stops calling them.
class _PowerlessBanner extends StatelessWidget {
  const _PowerlessBanner();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.screen, 8, AppSpacing.screen, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.warnBg,
        borderRadius: BorderRadius.circular(AppRadii.button),
      ),
      child: Row(
        spacing: 10,
        children: [
          Icon(AppIcons.elder, size: 18, color: colors.warnText),
          Expanded(
            child: Text(
              context.l10n.scriptPowerless,
              style: context.typography.meta.copyWith(color: colors.warnText, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// The table looks decided: says so and offers to end the game. Never ends it by itself, and
/// the game can be played on.
class _VictoryProposalBanner extends StatelessWidget {
  const _VictoryProposalBanner({required this.winner, required this.onEnd});

  final GameWinner winner;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.screen, 8, AppSpacing.screen, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.accentBg,
        borderRadius: BorderRadius.circular(AppRadii.button),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Icon(AppIcons.endGame, size: 18, color: colors.accentText),
              Expanded(
                child: Text(
                  context.l10n.victoryProposal(winner.name),
                  style: typography.meta.copyWith(color: colors.accentText, height: 1.5),
                ),
              ),
            ],
          ),
          AppButton(label: context.l10n.endGameTitle, compact: true, onPressed: onEnd),
        ],
      ),
    );
  }
}

List<Candidate> _alive(GameState engine) => [
  for (final p in engine.alivePlayers) (id: p.id, name: p.name),
];

/// The roles the composition still has spare copies of, given what the roster
/// already pins down. The candidate cards for a post-mortem reveal and for the
/// Voyante noting an as-yet-unknown player.
List<({String roleId, int remaining})> unassignedRoles(GameSessionState session) {
  final assigned = <String, int>{};
  for (final r in session.roster) {
    final id = r.roleId;
    if (id != null) assigned[id] = (assigned[id] ?? 0) + 1;
  }
  // The Voleur's own card is spent the moment he swaps into a reserve role - his roster entry
  // then carries the stolen role's id, not 'voleur', so the composition's one 'voleur' slot
  // would otherwise look perpetually unassigned. Keeping his own card needs no such fix:
  // voleurSwapIn stays null then, and the roster entry still carries 'voleur', already
  // counted above.
  if (session.voleurSwapIn != null) {
    assigned['voleur'] = (assigned['voleur'] ?? 0) + 1;
  }
  return [
    for (final e in session.dealtComposition.entries)
      if (e.value - (assigned[e.key] ?? 0) > 0)
        (roleId: e.key, remaining: e.value - (assigned[e.key] ?? 0)),
  ];
}

/// Divides the village in two groups, for the Abominable Sectaire: the MJ picks the first, and
/// everybody else is the second. Optional: it can be passed.
class _DivideAct extends StatefulWidget {
  const _DivideAct({required this.candidates, required this.onConfirm, required this.onSkip});

  final List<Candidate> candidates;
  final ValueChanged<Set<String>> onConfirm;
  final VoidCallback onSkip;

  @override
  State<_DivideAct> createState() => _DivideActState();
}

class _DivideActState extends State<_DivideAct> {
  final _first = <String>{};

  @override
  Widget build(BuildContext context) {
    // Both groups need someone.
    final valid = _first.isNotEmpty && _first.length < widget.candidates.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 18, AppSpacing.screen, 10),
          child: Text(
            context.l10n.scriptDivideQuestion,
            style: context.typography.rowLabel.copyWith(color: context.colors.textPrimary),
          ),
        ),
        Expanded(
          child: GridView.count(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            crossAxisCount: AppSizes.gridColumnsDefault,
            mainAxisSpacing: AppSpacing.gridGapRow,
            crossAxisSpacing: AppSpacing.gridGapColumn,
            childAspectRatio: 1.0,
            children: [
              for (final c in widget.candidates)
                AvatarPickCell(
                  name: c.name,
                  selected: _first.contains(c.id),
                  onTap: () => setState(() {
                    if (!_first.remove(c.id)) _first.add(c.id);
                  }),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            12,
            AppSpacing.screen,
            AppSpacing.screen,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              AppButton(
                label: valid
                    ? context.l10n.scriptDivideConfirm(_first.length)
                    : context.l10n.scriptDividePick,
                onPressed: valid ? () => widget.onConfirm({..._first}) : null,
              ),
              AppButton(
                label: context.l10n.scriptSkipRole,
                variant: AppButtonVariant.secondary,
                onPressed: widget.onSkip,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The Bear Tamer's growl, right after the victims are named. The app says whether it expects
/// one from the roles it knows; the MJ, who knows the table, does what is right.
class _BearGrowlBody extends StatelessWidget {
  const _BearGrowlBody({required this.session, required this.notifier});

  final GameSessionState session;
  final GameSession notifier;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final bear = session.bearTamer;
    if (bear == null) {
      // He died since: nothing to growl, on with the day.
      WidgetsBinding.instance.addPostFrameCallback((_) => notifier.bearGrowlDone(growled: false));
      return const SizedBox.shrink();
    }
    final around = session.engine.aliveNeighbours(bear.id);
    final neighbours = joinNames(context.l10n, [
      for (final p in {?around.left, ?around.right}) p.name,
    ]);
    final expected = session.bearShouldGrowl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 18, AppSpacing.screen, 8),
          child: Text(
            context.l10n.scriptGrowlTitle,
            style: typography.rowLabel.copyWith(color: colors.textPrimary),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 8),
          child: NarrationBlock(lines: growlNarration(context.l10n)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 6),
          child: Text(
            context.l10n.scriptGrowlWho(bear.name, neighbours),
            style: typography.body.copyWith(color: colors.textSecondary, height: 1.5),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 0),
          child: Text(
            expected ? context.l10n.scriptGrowlExpected : context.l10n.scriptGrowlNotExpected,
            style: typography.meta.copyWith(color: colors.textTertiary, height: 1.5),
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            0,
            AppSpacing.screen,
            AppSpacing.screen,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              AppButton(
                label: expected ? context.l10n.scriptGrowlDo : context.l10n.scriptGrowlNone,
                onPressed: () => notifier.bearGrowlDone(growled: expected),
              ),
              AppButton(
                label: expected ? context.l10n.scriptGrowlNone : context.l10n.scriptGrowlDo,
                variant: AppButtonVariant.secondary,
                onPressed: () => notifier.bearGrowlDone(growled: !expected),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The day recap - what the MJ reads aloud when the village wakes.
class _DayRecapBody extends StatelessWidget {
  const _DayRecapBody({required this.session, required this.onAdvance});

  final GameSessionState session;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final engine = session.engine;
    final deaths = session.recapDeaths;
    final saved = session.day.savedFromWolvesName;

    final wolvesAlive = engine.aliveWolves(RoleRegistry.all);
    final villageAlive = engine.alivePlayers.length - wolvesAlive;

    final ctaLabel = switch (nextDayStage(DayStage.recap, engine)) {
      DayStage.growl => context.l10n.scriptOpenGrowl,
      DayStage.captain => context.l10n.scriptElectCaptain,
      _ => context.l10n.scriptOpenVote,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        16,
        AppSpacing.screen,
        AppSpacing.screen,
      ),
      children: [
        _PhaseEyebrow(
          icon: AppIcons.day,
          label: context.l10n.scriptDayRises(engine.nightIndex),
          iconColor: colors.warnText,
        ),
        const SizedBox(height: 14),
        NarrationBlock(
          lines: morningNarration(context.l10n, [for (final d in deaths) d.name]),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.bgInset,
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                deaths.isEmpty
                    ? context.l10n.scriptNobodyDied
                    : context.l10n.scriptVillageLost,
                style: typography.meta.copyWith(color: colors.textTertiary),
              ),
              for (final death in deaths) ...[
                const SizedBox(height: 12),
                _RecapDeathRow(
                  name: death.name,
                  roleId: session.rosterRoleId(death.id),
                  cause: deathCauseLabel(context.l10n, death.causeOfDeath!),
                ),
              ],
              if (saved != null) ...[
                const SizedBox(height: 12),
                Divider(color: colors.borderHairline, height: 1),
                const SizedBox(height: 12),
                Text(
                  context.l10n.scriptSavedNote(saved),
                  style: typography.meta.copyWith(color: colors.textSecondary, height: 1.5),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: _StatCell(
                label: context.l10n.compositionVillage,
                value: villageAlive,
              ),
            ),
            Expanded(
              child: _StatCell(
                label: context.l10n.compositionWolves,
                value: wolvesAlive,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppButton(label: ctaLabel, onPressed: onAdvance),
      ],
    );
  }
}

/// One death in the day recap: avatar, name, the card that's turned over (the
/// point the MJ reads to the table), then the cause underneath.
class _RecapDeathRow extends StatelessWidget {
  const _RecapDeathRow({required this.name, required this.roleId, required this.cause});

  final String name;
  final String? roleId;
  final String cause;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final id = roleId;
    final role = id == null ? null : RoleRegistry.all.byIdOrNull(id);
    return Row(
      spacing: 12,
      children: [
        PlayerAvatar(name: name, size: AppSizes.avatarDayRecap, fillColor: colors.bgScreen),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: typography.rowLabel.copyWith(fontSize: 16, color: colors.textPrimary),
              ),
              const SizedBox(height: 2),
              Row(
                spacing: 5,
                children: [
                  Icon(
                    role == null ? AppIcons.help : _roleIcon(role.id),
                    size: 13,
                    color: colors.textPrimary,
                  ),
                  Flexible(
                    child: Text(
                      role == null
                          ? context.l10n.scriptRoleNotRevealed
                          : context.l10n.scriptWasRole(context.l10n.roleWithArticle(role.id)),
                      style: typography.meta.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                cause,
                style: typography.counter.copyWith(color: colors.textTertiary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Electing the Capitaine (day 1, and again on every captain death via the
/// chain panel). All living players, unfiltered by role, amber selection.
class _CaptainElectionBody extends StatelessWidget {
  const _CaptainElectionBody({required this.session, required this.notifier});

  final GameSessionState session;
  final GameSession notifier;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DayEyebrow(label: context.l10n.summaryPhase('day', session.engine.nightIndex)),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 12),
          child: _RoleBanner(
            icon: AppIcons.captain,
            title: context.l10n.scriptCaptainTitle,
            body: context.l10n.scriptCaptainBody,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 12),
          child: NarrationBlock(lines: captainNarration(context.l10n)),
        ),
        Expanded(
          child: TargetPick(
            question: context.l10n.scriptCaptainQuestion,
            candidates: _alive(session.engine),
            selectedStyle: AvatarSelectedStyle.captain,
            confirmIcon: AppIcons.captain,
            confirmLabel: context.l10n.scriptCaptainIs,
            onConfirm: (id) => notifier.electCaptain(id),
            secondaryLabel: context.l10n.scriptNoCaptain,
            onSecondary: () => notifier.electCaptain(null),
          ),
        ),
      ],
    );
  }
}

/// The village vote. 44px avatars (the largest in the app); the current
/// captain's avatar carries a crown badge.
/// Where the vote is: the usual pick, or what a tie asks next.
enum _VoteMode { vote, askScapegoat, tieBreak }

class _VoteBody extends ConsumerStatefulWidget {
  const _VoteBody({super.key, required this.session, required this.notifier});

  final GameSessionState session;
  final GameSession notifier;

  @override
  ConsumerState<_VoteBody> createState() => _VoteBodyState();
}

class _VoteBodyState extends ConsumerState<_VoteBody> {
  _VoteMode _mode = _VoteMode.vote;

  GameSessionState get _session => widget.session;
  GameSession get _notifier => widget.notifier;

  VoteTieRule get _rule => ref.read(settingsProvider).value?.voteTieRule ?? VoteTieRule.nobody;

  /// The village votes against [id]: the Village Idiot, when it is one, is pardoned.
  Future<void> _eliminate(String id) async {
    if (_session.mayBeIdiot(id)) {
      final name = _session.engine.playerById(id).name;
      final isIdiot = await showIdiotQuestion(context, name: name);
      if (isIdiot == true) {
        await _notifier.identifyRole('idiot_du_village', [int.parse(id)]);
      }
    }
    await _notifier.eliminateByVote(id);
  }

  /// The vote is tied: the Scapegoat first, then what the table decided for a tie.
  Future<void> _tie() async {
    final goat = _session.knownScapegoat;
    if (goat != null) {
      await _notifier.voteTiedOnScapegoat(goat.id);
    } else if (_session.scapegoatMayBeAlive) {
      setState(() => _mode = _VoteMode.askScapegoat);
    } else {
      await _tieWithoutScapegoat();
    }
  }

  Future<void> _tieWithoutScapegoat() async {
    final captainAlive = _session.engine.captainPlayerId != null;
    if (_rule == VoteTieRule.nobody || (_rule == VoteTieRule.captainDecides && !captainAlive)) {
      await _notifier.eliminateByVote(null);
    } else {
      setState(() => _mode = _VoteMode.tieBreak);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final engine = _session.engine;
    final captainId = engine.captainPlayerId;
    final captainName = captainId == null ? null : engine.playerById(captainId).name;
    final voters = engine.votersToday;
    final second = _session.day.stage == DayStage.secondVote;
    final pardoned = [
      for (final p in engine.alivePlayers)
        if (p.hasStatus(PlayerStatus.pardoned)) p.name,
    ];

    final Widget pick;
    switch (_mode) {
      case _VoteMode.askScapegoat:
        pick = TargetPick(
          question: context.l10n.scriptScapegoatAsk,
          candidates: _alive(engine),
          confirmLabel: context.l10n.scriptScapegoatIs,
          onConfirm: (id) async {
            await _notifier.identifyRole('bouc_emissaire', [int.parse(id)]);
            await _notifier.voteTiedOnScapegoat(id);
          },
          secondaryLabel: context.l10n.scriptScapegoatNone,
          onSecondary: () {
            setState(() => _mode = _VoteMode.vote);
            _tieWithoutScapegoat();
          },
        );
      case _VoteMode.tieBreak:
        pick = TargetPick(
          question: _rule == VoteTieRule.captainDecides
              ? context.l10n.scriptTieCaptain
              : context.l10n.scriptTieRevote,
          candidates: _alive(engine),
          avatarSize: AppSizes.avatarVoteGrid,
          crossAxisCount: AppSizes.gridColumnsSmallPool,
          confirmLabel: context.l10n.scriptVoteEliminates,
          onConfirm: _eliminate,
          secondaryLabel: context.l10n.scriptTieNobody,
          onSecondary: () => _notifier.eliminateByVote(null),
        );
      case _VoteMode.vote:
        pick = TargetPick(
          question: context.l10n.scriptVoteQuestion,
          candidates: _alive(engine),
          avatarSize: AppSizes.avatarVoteGrid,
          crossAxisCount: AppSizes.gridColumnsSmallPool,
          confirmLabel: context.l10n.scriptVoteEliminates,
          onConfirm: _eliminate,
          badgeFor: (c) => c.id == captainId
              ? Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(color: colors.bgScreen, shape: BoxShape.circle),
                  child: Icon(AppIcons.captain, size: 11, color: colors.warnText),
                )
              : null,
          secondaryLabel: voters != null && voters.isEmpty
              ? context.l10n.scriptVoteNobodyVotes
              : context.l10n.scriptVoteTie,
          onSecondary: voters != null && voters.isEmpty
              ? () => _notifier.eliminateByVote(null)
              : _tie,
        );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DayEyebrow(
          label: second
              ? context.l10n.scriptSecondVoteEyebrow(engine.nightIndex)
              : context.l10n.scriptVoteEyebrow(engine.nightIndex),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 12),
          child: _RoleBanner(
            icon: AppIcons.vote,
            title: second ? context.l10n.scriptSecondVoteTitle : context.l10n.scriptVoteTitle,
            body: second
                ? context.l10n.scriptSecondVoteBody
                : captainName == null
                ? context.l10n.scriptVoteBody
                : context.l10n.scriptVoteBodyCaptain(captainName),
          ),
        ),
        if (_session.judgeCanSign)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 8),
            child: AppButton(
              label: context.l10n.scriptJudgeSign,
              variant: AppButtonVariant.secondary,
              leadingIcon: AppIcons.judge,
              onPressed: _notifier.judgeSign,
            ),
          )
        else if (!second && engine.secondVoteToday)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 8),
            child: Text(
              context.l10n.scriptJudgeSignDone,
              style: context.typography.meta.copyWith(color: colors.warnText, height: 1.5),
            ),
          ),
        if (voters != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 8),
            child: Text(
              voters.isEmpty
                  ? context.l10n.scriptVotersNobody
                  : context.l10n.scriptVotersOnly(
                      joinNames(context.l10n, [for (final id in voters) engine.playerById(id).name]),
                    ),
              style: context.typography.meta.copyWith(color: colors.warnText, height: 1.5),
            ),
          ),
        if (pardoned.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 8),
            child: Text(
              context.l10n.scriptVotersPardoned(joinNames(context.l10n, pardoned)),
              style: context.typography.meta.copyWith(color: colors.textTertiary, height: 1.5),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 12),
          child: NarrationBlock(lines: voteNarration(context.l10n)),
        ),
        Expanded(child: pick),
      ],
    );
  }
}

class _NextNightPrompt extends StatelessWidget {
  const _NextNightPrompt({required this.nextNight, required this.onStart, this.note});

  final int nextNight;
  final VoidCallback onStart;

  /// What happened to close the day when it was not an elimination (the Idiot's pardon).
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (note != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 10),
            child: Text(
              note!,
              style: context.typography.body.copyWith(color: context.colors.warnText),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 10),
          child: Text(
            context.l10n.scriptDayOver,
            style: context.typography.body.copyWith(color: context.colors.textSecondary),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            0,
            AppSpacing.screen,
            AppSpacing.screen,
          ),
          child: AppButton(
            label: context.l10n.scriptStartNight(nextNight),
            leadingIcon: AppIcons.night,
            onPressed: onStart,
          ),
        ),
      ],
    );
  }
}

// --- interrupt panels (sheet-styled bodies, not real modals) ---

/// The reveal sheet: a dead player whose card was never recorded.
class _RevealPanel extends StatefulWidget {
  const _RevealPanel({required this.session, required this.notifier});

  final GameSessionState session;
  final GameSession notifier;

  @override
  State<_RevealPanel> createState() => _RevealPanelState();
}

class _RevealPanelState extends State<_RevealPanel> {
  String? _roleId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final dead = widget.session.unrevealedDead.first;
    final options = unassignedRoles(widget.session);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetHandle(),
        _DeadHeader(
          name: dead.name,
          subtitle: context.l10n.scriptEliminatedNight(dead.diedOnNight ?? 0),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, 0),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.bgInset,
              borderRadius: BorderRadius.circular(AppRadii.cardSmall),
            ),
            child: Text(
              context.l10n.scriptRevealHint,
              style: typography.meta.copyWith(color: colors.textSecondary, height: 1.5),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 12, AppSpacing.screen, 0),
          child: NarrationBlock(lines: revealNarration(context.l10n, dead.name)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 18, AppSpacing.screen, 8),
          child: Text(
            context.l10n.scriptRevealQuestion,
            style: typography.meta.copyWith(color: colors.textTertiary),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            children: [
              for (final o in options)
                _RoleOption(
                  roleId: o.roleId,
                  remaining: o.remaining,
                  selected: o.roleId == _roleId,
                  onTap: () => setState(() => _roleId = o.roleId),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            12,
            AppSpacing.screen,
            AppSpacing.screen,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              AppButton(
                label: _roleId == null
                    ? context.l10n.scriptPickCard
                    : context.l10n.scriptNameWas(dead.name, context.l10n.roleWithArticle(_roleId!)),
                onPressed: _roleId == null
                    ? null
                    : () => widget.notifier.revealRole(int.parse(dead.id), _roleId!),
              ),
              AppButton(
                label: context.l10n.scriptDontNote,
                variant: AppButtonVariant.secondary,
                onPressed: () => widget.notifier.skipReveal(dead.id),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.roleId,
    required this.remaining,
    required this.selected,
    required this.onTap,
  });

  final String roleId;
  final int remaining;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? colors.accentBg : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.button),
          border: Border.all(
            color: selected ? colors.accentBorder : colors.borderControl,
          ),
        ),
        child: Row(
          spacing: 12,
          children: [
            Icon(
              _roleIcon(roleId),
              size: 18,
              color: selected ? colors.accentText : colors.textSecondary,
            ),
            Expanded(
              child: Text(
                context.l10n.roleName(roleId),
                style: typography.rowLabel.copyWith(
                  color: selected ? colors.accentText : colors.textPrimary,
                ),
              ),
            ),
            if (remaining > 1)
              Text(
                context.l10n.scriptRemaining(remaining),
                style: typography.counter.copyWith(color: colors.textTertiary),
              ),
          ],
        ),
      ),
    );
  }
}

/// A death that triggers something: the Hunter's shot or the captain's
/// succession. The app names the consequence and hands over the picker.
class _ChainPanel extends StatelessWidget {
  const _ChainPanel({required this.session, required this.notifier});

  final GameSessionState session;
  final GameSession notifier;

  @override
  Widget build(BuildContext context) {
    final decision = session.engine.cascade!.decision;
    return switch (decision) {
      PendingHunterShot(:final deadHunterId) => _HunterShotPanel(
        session: session,
        notifier: notifier,
        deadHunterId: deadHunterId,
      ),
      PendingCaptainSuccession(:final deadCaptainId) => _SuccessionPanel(
        session: session,
        notifier: notifier,
        deadCaptainId: deadCaptainId,
      ),
      PendingKnightWound(:final deadKnightId) => _KnightWoundPanel(
        session: session,
        notifier: notifier,
        deadKnightId: deadKnightId,
      ),
      PendingScapegoatVoters(:final deadScapegoatId) => _ScapegoatVotersPanel(
        session: session,
        notifier: notifier,
        deadScapegoatId: deadScapegoatId,
      ),
    };
  }
}

class _HunterShotPanel extends StatelessWidget {
  const _HunterShotPanel({
    required this.session,
    required this.notifier,
    required this.deadHunterId,
  });

  final GameSessionState session;
  final GameSession notifier;
  final String deadHunterId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final hunter = session.engine.playerById(deadHunterId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetHandle(),
        _DeadHeader(
          name: hunter.name,
          subtitle: context.l10n.scriptEliminatedNight(hunter.diedOnNight ?? 0),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, 0),
          child: _RevealedCard(roleId: session.rosterRoleId(deadHunterId)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 12, AppSpacing.screen, 0),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.warnBg,
              borderRadius: BorderRadius.circular(AppRadii.button),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                Icon(AppIcons.hunter, size: 17, color: colors.warnText),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: context.l10n.scriptHunterShoots,
                          style: typography.meta.copyWith(
                            color: colors.warnText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextSpan(
                          text: context.l10n.scriptHunterTakes,
                          style: typography.meta.copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 12, AppSpacing.screen, 0),
          child: NarrationBlock(lines: hunterNarration(context.l10n)),
        ),
        Expanded(
          child: TargetPick(
            question: context.l10n.scriptHunterTarget,
            candidates: _alive(session.engine),
            crossAxisCount: AppSizes.gridColumnsSmallPool,
            confirmLabel: context.l10n.scriptHunterEliminated,
            onConfirm: (id) => notifier.hunterShoot(id),
            secondaryLabel: context.l10n.scriptHunterNoShot,
            onSecondary: () => notifier.hunterShoot(null),
          ),
        ),
      ],
    );
  }
}

class _SuccessionPanel extends StatelessWidget {
  const _SuccessionPanel({
    required this.session,
    required this.notifier,
    required this.deadCaptainId,
  });

  final GameSessionState session;
  final GameSession notifier;
  final String deadCaptainId;

  @override
  Widget build(BuildContext context) {
    final dead = session.engine.playerById(deadCaptainId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetHandle(),
        _DeadHeader(name: dead.name, subtitle: context.l10n.scriptCaptainDead),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, 12),
          child: _RoleBanner(
            icon: AppIcons.captain,
            title: context.l10n.scriptSuccessionTitle,
            body: context.l10n.scriptSuccessionBody,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 12),
          child: NarrationBlock(lines: successionNarration(context.l10n)),
        ),
        Expanded(
          child: TargetPick(
            question: context.l10n.scriptSuccessionQuestion,
            candidates: _alive(session.engine),
            selectedStyle: AvatarSelectedStyle.captain,
            confirmIcon: AppIcons.captain,
            confirmLabel: context.l10n.scriptCaptainBecomes,
            onConfirm: (id) => notifier.nameCaptainSuccessor(id),
            secondaryLabel: context.l10n.scriptSuccessionNone,
            onSecondary: notifier.captainHasNoSuccessor,
          ),
        ),
      ],
    );
  }
}

/// The Knight was devoured: which wolf does his rusty sword leave diseased? The app suggests the
/// first wolf to his left among the cards it knows; the MJ, who knows the table, decides.
class _KnightWoundPanel extends ConsumerWidget {
  const _KnightWoundPanel({
    required this.session,
    required this.notifier,
    required this.deadKnightId,
  });

  final GameSessionState session;
  final GameSession notifier;
  final String deadKnightId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final knight = session.engine.playerById(deadKnightId);
    final suggested = session.engine.firstWolfToLeftOf(deadKnightId, RoleRegistry.all);
    final atEnd = ref.watch(settingsProvider).value?.knightDiseaseAtNightEnd ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetHandle(),
        _DeadHeader(name: knight.name, subtitle: context.l10n.scriptKnightDead),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, 12),
          child: _RoleBanner(
            icon: AppIcons.knight,
            title: context.l10n.scriptKnightTitle,
            body: atEnd ? context.l10n.scriptKnightBodyEnd : context.l10n.scriptKnightBodyStart,
          ),
        ),
        if (suggested != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 8),
            child: Text(
              context.l10n.scriptKnightSuggested(suggested.name),
              style: context.typography.meta.copyWith(
                color: context.colors.textTertiary,
                height: 1.5,
              ),
            ),
          ),
        Expanded(
          child: TargetPick(
            question: context.l10n.scriptKnightQuestion,
            candidates: _alive(session.engine),
            confirmLabel: context.l10n.scriptKnightWounds,
            onConfirm: notifier.knightContaminate,
            secondaryLabel: context.l10n.scriptKnightNone,
            onSecondary: () => notifier.knightContaminate(null),
          ),
        ),
      ],
    );
  }
}

/// The Scapegoat was eliminated: who may vote on the next day? The ones not chosen sit it out.
class _ScapegoatVotersPanel extends StatefulWidget {
  const _ScapegoatVotersPanel({
    required this.session,
    required this.notifier,
    required this.deadScapegoatId,
  });

  final GameSessionState session;
  final GameSession notifier;
  final String deadScapegoatId;

  @override
  State<_ScapegoatVotersPanel> createState() => _ScapegoatVotersPanelState();
}

class _ScapegoatVotersPanelState extends State<_ScapegoatVotersPanel> {
  final _chosen = <String>{};

  @override
  Widget build(BuildContext context) {
    final engine = widget.session.engine;
    final goat = engine.playerById(widget.deadScapegoatId);
    final alive = _alive(engine);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetHandle(),
        _DeadHeader(name: goat.name, subtitle: context.l10n.scriptScapegoatDead),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, 12),
          child: _RoleBanner(
            icon: AppIcons.scapegoat,
            title: context.l10n.scriptScapegoatTitle,
            body: context.l10n.scriptScapegoatBody,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 8),
          child: Text(
            context.l10n.scriptScapegoatQuestion,
            style: context.typography.rowLabel.copyWith(color: context.colors.textPrimary),
          ),
        ),
        Expanded(
          child: GridView.count(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            crossAxisCount: AppSizes.gridColumnsDefault,
            mainAxisSpacing: AppSpacing.gridGapRow,
            crossAxisSpacing: AppSpacing.gridGapColumn,
            childAspectRatio: 1.0,
            children: [
              for (final c in alive)
                AvatarPickCell(
                  name: c.name,
                  selected: _chosen.contains(c.id),
                  onTap: () => setState(() {
                    if (!_chosen.remove(c.id)) _chosen.add(c.id);
                  }),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            12,
            AppSpacing.screen,
            AppSpacing.screen,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              AppButton(
                label: _chosen.isEmpty
                    ? context.l10n.scriptScapegoatNobody
                    : context.l10n.scriptScapegoatVoters(_chosen.length),
                onPressed: () => widget.notifier.chooseVoters({..._chosen}),
              ),
              AppButton(
                label: context.l10n.scriptScapegoatEveryone,
                variant: AppButtonVariant.secondary,
                onPressed: () => widget.notifier.chooseVoters({for (final c in alive) c.id}),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoversAckPanel extends StatelessWidget {
  const _LoversAckPanel({required this.session, required this.notifier});

  final GameSessionState session;
  final GameSession notifier;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final lover = session.engine.playerById(session.day.loversAck.first);
    final partnerId = session.engine.lovers?.partnerOf(lover.id);
    final partnerName = partnerId == null
        ? null
        : session.engine.playerById(partnerId).name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetHandle(),
        _DeadHeader(
          name: lover.name,
          subtitle: partnerName == null
              ? context.l10n.scriptDiesOfHeartbreak
              : context.l10n.scriptInLoveWith(partnerName),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, 0),
          child: _RevealedCard(roleId: session.rosterRoleId(lover.id)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 12, AppSpacing.screen, 0),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.warnBg,
              borderRadius: BorderRadius.circular(AppRadii.button),
            ),
            child: Text(
              partnerName == null
                  ? context.l10n.scriptLoversNoPartner
                  : context.l10n.scriptLoversPartner(partnerName, lover.name),
              style: typography.meta.copyWith(color: colors.textSecondary, height: 1.5),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 12, AppSpacing.screen, 0),
          child: NarrationBlock(lines: loversNarration(context.l10n, lover.name)),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            0,
            AppSpacing.screen,
            AppSpacing.screen,
          ),
          child: AppButton(label: context.l10n.scriptGotIt, onPressed: notifier.acknowledgeLoversDeaths),
        ),
      ],
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: context.colors.borderHairline,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
    ),
  );
}

class _DeadHeader extends StatelessWidget {
  const _DeadHeader({required this.name, required this.subtitle});

  final String name;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 18, AppSpacing.screen, 0),
      child: Column(
        children: [
          PlayerAvatar(name: name, size: AppSizes.avatarDeathSheet, fillColor: colors.bgInset),
          const SizedBox(height: 10),
          Text(
            name,
            style: typography.rowLabel.copyWith(fontSize: 19, color: colors.textPrimary),
          ),
          Text(subtitle, style: typography.meta.copyWith(color: colors.textSecondary)),
        ],
      ),
    );
  }
}

class _RevealedCard extends StatelessWidget {
  const _RevealedCard({required this.roleId});

  /// Null when the MJ never recorded this player's card.
  final String? roleId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final id = roleId;
    final role = id == null ? null : RoleRegistry.all.byIdOrNull(id);
    final wolves = role?.team == Team.werewolves;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.bgInset,
        borderRadius: BorderRadius.circular(AppRadii.cardSmall),
      ),
      child: Row(
        spacing: 12,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: colors.bgScreen, shape: BoxShape.circle),
            child: Icon(
              role == null ? AppIcons.help : _roleIcon(role.id),
              size: 18,
              color: colors.textPrimary,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.scriptTheirCard, style: typography.counter.copyWith(color: colors.textTertiary)),
                Text(
                  role == null ? context.l10n.scriptRoleNotRevealed : context.l10n.roleName(role.id),
                  style: typography.rowLabel.copyWith(color: colors.textPrimary),
                ),
              ],
            ),
          ),
          if (role != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: wolves ? colors.accentBg : colors.bgScreen,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                wolves ? context.l10n.compositionWolves : context.l10n.compositionVillage,
                style: typography.counter.copyWith(
                  color: wolves ? colors.accentText : colors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoleBanner extends StatelessWidget {
  const _RoleBanner({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.bgInset,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            spacing: 10,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: colors.warnBg, shape: BoxShape.circle),
                child: Icon(icon, size: 17, color: colors.warnText),
              ),
              Expanded(
                child: Text(
                  title,
                  style: typography.rowLabel.copyWith(fontSize: 16, color: colors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: typography.body.copyWith(color: colors.textSecondary, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _DayEyebrow extends StatelessWidget {
  const _DayEyebrow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, 10),
      child: _PhaseEyebrow(
        icon: AppIcons.day,
        label: label,
        iconColor: context.colors.warnText,
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: colors.bgInset,
        borderRadius: BorderRadius.circular(AppRadii.button),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: typography.counter.copyWith(color: colors.textSecondary)),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$value ',
                  style: typography.rowLabel.copyWith(fontSize: 20, color: colors.textPrimary),
                ),
                TextSpan(
                  text: context.l10n.scriptAliveUnit,
                  style: typography.counter.copyWith(color: colors.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
