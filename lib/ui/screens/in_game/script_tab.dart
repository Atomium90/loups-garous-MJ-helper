import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../../state/session/game_session.dart';
import '../../../state/session/session_cursor.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import 'widgets/identify_step.dart';

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
          : _DayRecapBody(session: session),
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
            child: _ScriptCard(
              role: step.role,
              holderNames: session.cursor.subStep == NightSubStep.act
                  ? _holderNames(step.role.id)
                  : const [],
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
    if (session.cursor.subStep == NightSubStep.identify) {
      return IdentifyStep(
        role: step.role,
        count: session.composition[step.role.id] ?? 1,
        candidates: [
          for (final p in session.engine.alivePlayers)
            (rowId: int.parse(p.id), name: p.name),
        ],
        onConfirm: (rowIds) => notifier.identifyRole(step.role.id, rowIds),
        onDefer: notifier.skipStep,
      );
    }
    // act sub-step - per-role widgets land in the next commit
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screen),
      child: Text(
        'Action « ${step.role.name} » — bientôt',
        style: context.typography.body.copyWith(color: context.colors.textTertiary),
      ),
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
  });

  final int nightIndex;
  final int stepCount;
  final int currentStep;
  final bool showDots;

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
  _ => AppIcons.village,
};

class _DayRecapBody extends StatelessWidget {
  const _DayRecapBody({required this.session});

  final GameSessionState session;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: Text(
          'Jour ${session.engine.nightIndex} — récap bientôt',
          style: context.typography.body.copyWith(color: context.colors.textTertiary),
        ),
      ),
    );
  }
}
