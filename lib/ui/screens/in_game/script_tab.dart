import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../../state/session/game_session.dart';
import '../../../state/session/session_cursor.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../utils/french_death_cause.dart';
import '../../utils/french_role_label.dart';
import '../../widgets/app_button.dart';
import '../../widgets/avatar_pick_cell.dart';
import '../../widgets/player_avatar.dart';
import 'widgets/aide_memoire_sheet.dart';
import 'widgets/identify_step.dart';
import 'widgets/simple_act.dart';
import 'widgets/target_pick.dart';
import 'widgets/witch_act.dart';

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
      error: (_, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Text(
            'Impossible de charger la partie.',
            textAlign: TextAlign.center,
            style: context.typography.body.copyWith(color: context.colors.textSecondary),
          ),
        ),
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
          onHelp: () => showAideMemoireSheet(context, session.composition),
        ),
        if (step != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 0),
            child: _ScriptCard(
              role: step.role,
              holderNames: session.currentStepNeedsIdentify
                  ? const []
                  : _holderNames(step.role.id),
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
            ? 'Le Voleur a volé une carte de ${step.role.name} : il compte en plus.'
            : 'Déjà connu grâce à la Voyante.',
        onConfirm: (rowIds) => notifier.identifyRole(roleId, rowIds),
        onDefer: notifier.skipStep,
      );
    }
    return _actBody(notifier, step.role);
  }

  Widget _actBody(GameSession notifier, Role role) {
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
          question: 'Qui les Loups dévorent-ils ?',
          candidates: [for (final p in alive) if (p.roleId != 'loup_garou') cand(p)],
          confirmLabel: (name) => 'Les Loups désignent $name',
          onConfirm: (id) => notifier.applyAction(WolvesTarget(targetPlayerId: id)),
          secondaryLabel: 'Passer ce rôle',
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
          return SimpleAct(primaryLabel: 'Passer ce rôle', onPrimary: notifier.skipStep);
        }
        return _VoleurAct(
          reserveRoleIds: session.reserveRoleIds,
          onConfirm: (stolenRoleId) => notifier.voleurSwap(
            voleurEngineId: voleur.id,
            stolenRoleId: stolenRoleId,
          ),
        );

      default:
        return SimpleAct(primaryLabel: 'Passer ce rôle', onPrimary: notifier.skipStep);
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
            'Les deux cartes de la pioche',
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
              'Le Voleur devient ${roleWithArticle(stolen!, RoleRegistry.base)} : '
              "réveillez-le à son tour cette nuit s'il n'est pas déjà passé.",
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
                ? 'Choisissez une carte'
                : keeps
                ? 'Le Voleur garde sa carte'
                : 'Le Voleur prend ${roleWithArticle(stolen!, RoleRegistry.base)}',
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
                'Il garde sa carte',
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
        question: 'Qui la Voyante observe-t-elle ?',
        candidates: [for (final t in widget.targets) (id: '${t.rowId}', name: t.name)],
        confirmLabel: (name) => 'La Voyante observe $name',
        onConfirm: _onTargetPicked,
        secondaryLabel: 'Passer ce rôle',
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
            'Sa carte n\'est pas encore notée. Montrez-la à la Voyante, puis notez-la.',
            style: typography.meta.copyWith(color: colors.textSecondary, height: 1.5),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 12, AppSpacing.screen, 8),
          child: Text(
            'La carte de ${widget.name}',
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
                ? 'Choisissez une carte'
                : '${widget.name} est ${roleWithArticle(_roleId!, RoleRegistry.base)}',
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
                  'La Voyante voit',
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
                        '$name est ${roleWithArticle(roleId, RoleRegistry.base)}',
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
                        wolves ? 'Loups' : 'Village',
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
          child: AppButton(label: 'Continuer', onPressed: onContinue),
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
                  'Qui sont les amoureux ?',
                  style: typography.rowLabel.copyWith(color: colors.textPrimary),
                ),
              ),
              Text(
                '${_selected.length} sur 2',
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
                    ? 'Cupidon unit ${_name(_selected[0])} et ${_name(_selected[1])}'
                    : 'Choisissez deux joueurs',
                leadingIcon: complete ? AppIcons.cupid : null,
                onPressed: complete
                    ? () => widget.onConfirm(_selected[0], _selected[1])
                    : null,
              ),
              AppButton(
                label: 'Passer ce rôle',
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
            'Tous les rôles ont joué.',
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
          child: AppButton(label: 'Résoudre la nuit', onPressed: onResolve),
        ),
      ],
    );
  }
}

class _NightHeader extends StatelessWidget {
  const _NightHeader({
    required this.nightIndex,
    required this.stepCount,
    required this.currentStep,
    required this.showDots,
    this.onHelp,
  });

  final int nightIndex;
  final int stepCount;
  final int currentStep;

  /// Night 1 shows step-progress dots. Later nights show a `?` that opens the
  /// aide-mémoire ([onHelp]) instead.
  final bool showDots;
  final VoidCallback? onHelp;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 22, AppSpacing.screen, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            spacing: 8,
            children: [
              Icon(AppIcons.night, size: 15, color: colors.textSecondary),
              Text(
                'Nuit $nightIndex',
                style: context.typography.body.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
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
            )
          else if (onHelp != null)
            GestureDetector(
              onTap: onHelp,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: AppSizes.iconButtonDense,
                height: AppSizes.iconButtonDense,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.borderHairline),
                ),
                child: Icon(AppIcons.help, size: 15, color: colors.textSecondary),
              ),
            ),
        ],
      ),
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
                      role.name,
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
            role.ruleText,
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
        ? 'Élire le Capitaine'
        : 'Ouvrir le vote du village';

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        22,
        AppSpacing.screen,
        AppSpacing.screen,
      ),
      children: [
        Row(
          spacing: 8,
          children: [
            Icon(AppIcons.day, size: 16, color: colors.warnText),
            Text(
              'Jour ${engine.nightIndex} se lève',
              style: typography.body.copyWith(color: colors.textSecondary),
            ),
          ],
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
                    ? "Personne n'est mort cette nuit"
                    : 'Cette nuit, le village a perdu',
                style: typography.meta.copyWith(color: colors.textTertiary),
              ),
              for (final death in deaths) ...[
                const SizedBox(height: 12),
                Row(
                  spacing: 12,
                  children: [
                    PlayerAvatar(
                      name: death.name,
                      size: AppSizes.avatarDayRecap,
                      fillColor: colors.bgScreen,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            death.name,
                            style: typography.rowLabel.copyWith(
                              fontSize: 16,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            frenchDeathCauseLabel(death.causeOfDeath!),
                            style: typography.meta.copyWith(color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              if (saved != null) ...[
                const SizedBox(height: 12),
                Divider(color: colors.borderHairline, height: 1),
                const SizedBox(height: 12),
                Text(
                  '$saved a été attaqué par les Loups, puis sauvé. Ne l\'annoncez pas.',
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
            Expanded(child: _StatCell(label: 'Village', value: aliveByTeam[Team.village] ?? 0)),
            Expanded(child: _StatCell(label: 'Loups', value: aliveByTeam[Team.werewolves] ?? 0)),
          ],
        ),
        const SizedBox(height: 16),
        AppButton(label: ctaLabel, onPressed: onAdvance),
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
        _DayEyebrow(label: 'Jour ${session.engine.nightIndex}'),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 12),
          child: const _RoleBanner(
            icon: AppIcons.captain,
            title: 'Le Capitaine',
            body: 'Le village élit son Capitaine. N\'importe quel joueur, quel que soit '
                'son rôle. Sa voix compte double au vote. Cet écran revient si le '
                'Capitaine meurt : il désigne alors son successeur.',
          ),
        ),
        Expanded(
          child: TargetPick(
            question: 'Qui est élu ?',
            candidates: _alive(session.engine),
            selectedStyle: AvatarSelectedStyle.captain,
            confirmIcon: AppIcons.captain,
            pendingLabel: 'Choisissez un joueur',
            confirmLabel: (name) => '$name est Capitaine',
            onConfirm: (id) => notifier.electCaptain(id),
            secondaryLabel: 'Pas de Capitaine cette partie',
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
        _DayEyebrow(label: 'Jour ${session.engine.nightIndex} · vote'),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 12),
          child: _RoleBanner(
            icon: AppIcons.vote,
            title: 'Le vote',
            body: captainName == null
                ? 'Le village débat, puis désigne.'
                : 'Le village débat, puis désigne. La voix de $captainName compte double.',
          ),
        ),
        Expanded(
          child: TargetPick(
            question: 'Qui est éliminé ?',
            candidates: _alive(session.engine),
            avatarSize: AppSizes.avatarVoteGrid,
            crossAxisCount: AppSizes.gridColumnsSmallPool,
            confirmLabel: (name) => 'Le village élimine $name',
            onConfirm: (id) => notifier.eliminateByVote(id),
            badgeFor: (c) => c.id == captainId
                ? Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(color: colors.bgScreen, shape: BoxShape.circle),
                    child: Icon(AppIcons.captain, size: 11, color: colors.warnText),
                  )
                : null,
            secondaryLabel: 'Égalité, personne n\'est éliminé',
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
            'Le jour est terminé.',
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
            label: 'Commencer la nuit $nextNight',
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
        _DeadHeader(name: dead.name, subtitle: 'Éliminé nuit ${dead.diedOnNight}'),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, 0),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.bgInset,
              borderRadius: BorderRadius.circular(AppRadii.cardSmall),
            ),
            child: Text(
              "Retournez sa carte devant la table. Son rôle n'a pas encore été noté.",
              style: typography.meta.copyWith(color: colors.textSecondary, height: 1.5),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 18, AppSpacing.screen, 8),
          child: Text(
            'Quelle était sa carte ?',
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
                    ? 'Choisissez une carte'
                    : '${dead.name} était ${roleWithArticle(_roleId!, RoleRegistry.base)}',
                onPressed: _roleId == null
                    ? null
                    : () => widget.notifier.revealRole(int.parse(dead.id), _roleId!),
              ),
              AppButton(
                label: 'Je ne note pas',
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
                RoleRegistry.base.byId(roleId).name,
                style: typography.rowLabel.copyWith(
                  color: selected ? colors.accentText : colors.textPrimary,
                ),
              ),
            ),
            if (remaining > 1)
              Text(
                '$remaining restants',
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
        _DeadHeader(name: hunter.name, subtitle: 'Éliminé nuit ${hunter.diedOnNight}'),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, 0),
          child: _RevealedCard(roleId: hunter.roleId),
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
                          text: 'Le Chasseur tire. ',
                          style: typography.meta.copyWith(
                            color: colors.warnText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextSpan(
                          text: 'Il emporte un joueur avec lui, tout de suite.',
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
        Expanded(
          child: TargetPick(
            question: 'Sa cible',
            candidates: _alive(session.engine),
            crossAxisCount: AppSizes.gridColumnsSmallPool,
            confirmLabel: (name) => '$name est éliminé',
            onConfirm: (id) => notifier.hunterShoot(id),
            secondaryLabel: 'Il ne tire pas',
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
        _DeadHeader(name: dead.name, subtitle: 'Le Capitaine est mort'),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, 12),
          child: const _RoleBanner(
            icon: AppIcons.captain,
            title: 'La succession',
            body: 'Avant de partir, le Capitaine désigne son successeur. '
                'Sa voix comptera double à son tour.',
          ),
        ),
        Expanded(
          child: TargetPick(
            question: 'Qui lui succède ?',
            candidates: _alive(session.engine),
            selectedStyle: AvatarSelectedStyle.captain,
            confirmIcon: AppIcons.captain,
            confirmLabel: (name) => '$name devient Capitaine',
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetHandle(),
        _DeadHeader(name: lover.name, subtitle: 'Meurt de chagrin'),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, 0),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.warnBg,
              borderRadius: BorderRadius.circular(AppRadii.button),
            ),
            child: Text(
              "L'autre amoureux ne survit pas à sa disparition. Annoncez-le au village.",
              style: typography.meta.copyWith(color: colors.textSecondary, height: 1.5),
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
          child: AppButton(label: 'Compris', onPressed: notifier.acknowledgeLoversDeaths),
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

  final String roleId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final role = RoleRegistry.base.byId(roleId);
    final wolves = role.team == Team.werewolves;
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
            child: Icon(_roleIcon(roleId), size: 18, color: colors.textPrimary),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sa carte', style: typography.counter.copyWith(color: colors.textTertiary)),
                Text(
                  role.name,
                  style: typography.rowLabel.copyWith(color: colors.textPrimary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: wolves ? colors.accentBg : colors.bgScreen,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Text(
              wolves ? 'Loups' : 'Village',
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
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 22, AppSpacing.screen, 12),
      child: Row(
        spacing: 8,
        children: [
          Icon(AppIcons.day, size: 15, color: colors.warnText),
          Text(
            label,
            style: context.typography.body.copyWith(color: colors.textSecondary),
          ),
        ],
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
                  text: 'vivants',
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
