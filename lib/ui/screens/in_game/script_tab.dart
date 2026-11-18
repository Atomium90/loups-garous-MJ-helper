import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../../state/session/game_session.dart';
import '../../../state/session/session_cursor.dart';
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
import 'widgets/identify_step.dart';
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
      if (p.roleId == roleId) p.name,
  ];

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
                    // the first role of the night is preceded by "the village goes to sleep"
                    if (session.cursor.stepIndex == 0) ...nightStartNarration(context.l10n),
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

  Widget _body(BuildContext context, GameSession notifier, NightScriptStep? step) {
    if (step == null) {
      return _FinalizePrompt(onResolve: () => notifier.applyAction(const FinalizeNight()));
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
        count: (session.composition[roleId] ?? 1) - session.dealtHoldersKnown(roleId),
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
    return _actBody(context, notifier, step.role);
  }

  Widget _actBody(BuildContext context, GameSession notifier, Role role) {
    final alive = session.engine.alivePlayers;
    Candidate cand(Player p) => (id: p.id, name: p.name);

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

      case 'cupidon':
        return _LoversPick(
          candidates: [for (final p in alive) cand(p)],
          onConfirm: (a, b) => notifier.pairLovers(a, b),
          onSkip: notifier.skipStep,
        );

      case 'loup_garou':
        return TargetPick(
          question: context.l10n.scriptWolvesQuestion,
          candidates: [for (final p in alive) if (p.roleId != 'loup_garou') cand(p)],
          confirmLabel: context.l10n.scriptWolvesPick,
          onConfirm: (id) => notifier.applyAction(WolvesTarget(targetPlayerId: id)),
          secondaryLabel: context.l10n.scriptSkipRole,
          onSecondary: notifier.skipStep,
        );

      case 'sorciere':
        final victimId = session.engine.pendingWolfVictimId;
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
  const _VoleurAct({required this.reserveRoleIds, required this.onConfirm});

  final List<String> reserveRoleIds;

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
    final stolenRole = stolen == null ? null : RoleRegistry.base.byId(stolen);
    final stealsNightRole = stolenRole?.hasNightCall ?? false;

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
    final role = RoleRegistry.base.byId(roleId);
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
  });

  final List<Candidate> candidates;
  final void Function(String a, String b) onConfirm;
  final VoidCallback onSkip;

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
    final complete = _selected.length == 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 18, AppSpacing.screen, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.scriptLoversQuestion,
                  style: typography.rowLabel.copyWith(color: colors.textPrimary),
                ),
              ),
              Text(
                context.l10n.identifyProgress(_selected.length, 2),
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
                label: complete
                    ? context.l10n.scriptLoversPair(_name(_selected[0]), _name(_selected[1]))
                    : context.l10n.scriptLoversPick,
                leadingIcon: complete ? AppIcons.cupid : null,
                onPressed: complete
                    ? () => widget.onConfirm(_selected[0], _selected[1])
                    : null,
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

    return switch (session.day.stage) {
      DayStage.recap => _DayRecapBody(session: session, onAdvance: n.advanceFromRecap),
      DayStage.captain => _CaptainElectionBody(session: session, notifier: n),
      DayStage.vote => _VoteBody(session: session, notifier: n),
      DayStage.done => _NextNightPrompt(
        nextNight: session.engine.nightIndex + 1,
        onStart: n.startNextNight,
      ),
    };
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
    for (final e in session.composition.entries)
      if (e.value - (assigned[e.key] ?? 0) > 0)
        (roleId: e.key, remaining: e.value - (assigned[e.key] ?? 0)),
  ];
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

    final aliveByTeam = <Team, int>{};
    for (final p in engine.alivePlayers) {
      final team = RoleRegistry.base.byIdOrNull(p.roleId)?.team ?? Team.village;
      aliveByTeam[team] = (aliveByTeam[team] ?? 0) + 1;
    }

    final ctaLabel = engine.nightIndex == 1 && engine.captainPlayerId == null
        ? context.l10n.scriptElectCaptain
        : context.l10n.scriptOpenVote;

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
                value: aliveByTeam[Team.village] ?? 0,
              ),
            ),
            Expanded(
              child: _StatCell(
                label: context.l10n.compositionWolves,
                value: aliveByTeam[Team.werewolves] ?? 0,
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
    final role = id == null ? null : RoleRegistry.base.byIdOrNull(id);
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
class _VoteBody extends StatelessWidget {
  const _VoteBody({required this.session, required this.notifier});

  final GameSessionState session;
  final GameSession notifier;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final captainId = session.engine.captainPlayerId;
    final captainName = captainId == null ? null : session.engine.playerById(captainId).name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DayEyebrow(label: context.l10n.scriptVoteEyebrow(session.engine.nightIndex)),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 12),
          child: _RoleBanner(
            icon: AppIcons.vote,
            title: context.l10n.scriptVoteTitle,
            body: captainName == null
                ? context.l10n.scriptVoteBody
                : context.l10n.scriptVoteBodyCaptain(captainName),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 12),
          child: NarrationBlock(lines: voteNarration(context.l10n)),
        ),
        Expanded(
          child: TargetPick(
            question: context.l10n.scriptVoteQuestion,
            candidates: _alive(session.engine),
            avatarSize: AppSizes.avatarVoteGrid,
            crossAxisCount: AppSizes.gridColumnsSmallPool,
            confirmLabel: context.l10n.scriptVoteEliminates,
            onConfirm: (id) => notifier.eliminateByVote(id),
            badgeFor: (c) => c.id == captainId
                ? Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(color: colors.bgScreen, shape: BoxShape.circle),
                    child: Icon(AppIcons.captain, size: 11, color: colors.warnText),
                  )
                : null,
            secondaryLabel: context.l10n.scriptVoteTie,
            onSecondary: () => notifier.eliminateByVote(null),
          ),
        ),
      ],
    );
  }
}

class _NextNightPrompt extends StatelessWidget {
  const _NextNightPrompt({required this.nextNight, required this.onStart});

  final int nextNight;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
    final role = id == null ? null : RoleRegistry.base.byIdOrNull(id);
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
              Text(
                title,
                style: typography.rowLabel.copyWith(fontSize: 16, color: colors.textPrimary),
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
