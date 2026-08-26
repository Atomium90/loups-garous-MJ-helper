import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../../state/composition/composition_draft.dart';
import '../../../state/composition/composition_editor_notifier.dart';
import '../../../state/providers/game_repository_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/app_stepper.dart';

/// Minimum/maximum player count for the base box ("La boîte de base couvre 8 à 18 joueurs" -
/// see Réglages/Mes boîtes copy). Enforced here at the widget layer; [CompositionEditor] itself
/// only guards against negative counts. Should eventually live as real `RoleRegistry` metadata
/// once extensions widen the range per-box.
const _minPlayers = 8;
const _maxPlayers = 18;

/// The two roles whose count scales with player count (only wolves/villagers ever exceed 1 in
/// the base game) get an inline stepper instead of a plain tap-to-toggle chip.
const _scalingRoleIds = {'loup_garou', 'villageois'};

class CompositionScreen extends ConsumerWidget {
  const CompositionScreen({required this.gameId, super.key});

  final int gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftAsync = ref.watch(compositionEditorProvider(gameId));
    final notifier = ref.read(compositionEditorProvider(gameId).notifier);

    return Scaffold(
      body: SafeArea(
        child: draftAsync.when(
          data: (draft) => _CompositionBody(gameId: gameId, draft: draft, notifier: notifier),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screen),
              child: Text(
                'Impossible de charger cette partie.',
                textAlign: TextAlign.center,
                style: context.typography.body.copyWith(color: context.colors.textSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompositionBody extends StatelessWidget {
  const _CompositionBody({required this.gameId, required this.draft, required this.notifier});

  final int gameId;
  final CompositionDraft draft;
  final CompositionEditor notifier;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    final villageRoles = RoleRegistry.base.roles
        .where((r) => (r.team ?? Team.village) == Team.village)
        .toList(growable: false);
    final wolfRoles = RoleRegistry.base.roles
        .where((r) => (r.team ?? Team.village) == Team.werewolves)
        .toList(growable: false);

    return Column(
      children: [
        _Header(gameId: gameId, playerCount: draft.playerCount),
        _PlayerCountRow(
          playerCount: draft.playerCount,
          onChanged: notifier.setPlayerCount,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('Village', style: typography.meta.copyWith(color: colors.textTertiary)),
                ),
                _RoleGroup(roles: villageRoles, draft: draft, notifier: notifier),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('Loups', style: typography.meta.copyWith(color: colors.textTertiary)),
                ),
                _RoleGroup(roles: wolfRoles, draft: draft, notifier: notifier),
              ],
            ),
          ),
        ),
        _Footer(gameId: gameId, draft: draft, notifier: notifier),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.gameId, required this.playerCount});

  final int gameId;
  final int playerCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typography = context.typography;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 24, AppSpacing.screen, 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(AppIcons.back, size: 18, color: colors.textSecondary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
            onPressed: () async {
              // Every game reaching this screen got here via fresh "Nouvelle partie", so it's
              // always still GameStatus.setup here - exactly what discardDraft exists for.
              await ref.read(gameRepositoryProvider).discardDraft(gameId);
              if (context.mounted) context.go('/');
            },
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Composition', style: typography.screenTitle.copyWith(color: colors.textPrimary)),
              Text(
                '$playerCount joueurs',
                style: typography.meta.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlayerCountRow extends StatelessWidget {
  const _PlayerCountRow({required this.playerCount, required this.onChanged});

  final int playerCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.borderHairline),
          bottom: BorderSide(color: colors.borderHairline),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Joueurs',
              style: context.typography.body.copyWith(color: colors.textSecondary),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: AppStepper(
              value: playerCount,
              min: _minPlayers,
              max: _maxPlayers,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleGroup extends StatelessWidget {
  const _RoleGroup({required this.roles, required this.draft, required this.notifier});

  final List<Role> roles;
  final CompositionDraft draft;
  final CompositionEditor notifier;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final role in roles)
          _scalingRoleIds.contains(role.id)
              ? _RoleCountChip(
                  label: role.name,
                  count: draft.roleCounts[role.id] ?? 0,
                  max: draft.playerCount,
                  onChanged: (count) => notifier.setRoleCount(role.id, count),
                )
              : AppChip(
                  label: role.name,
                  selected: draft.roleCounts.containsKey(role.id),
                  onTap: () => notifier.toggleRole(role.id),
                ),
      ],
    );
  }
}

/// A pill combining a role's name with an inline stepper, for the two roles that can exceed
/// count 1 (loup_garou, villageois) - reuses the one increment/decrement affordance the design
/// already establishes (the player-count stepper) rather than inventing an undocumented gesture.
class _RoleCountChip extends StatelessWidget {
  const _RoleCountChip({
    required this.label,
    required this.count,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int count;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final selected = count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: selected ? colors.accentBg : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: selected ? colors.accentBorder : colors.borderHairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Text(
            label,
            style: typography.chipLabel.copyWith(
              color: selected ? colors.accentText : colors.textPrimary,
            ),
          ),
          AppStepper(value: count, min: 0, max: max, buttonSize: 20, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.gameId, required this.draft, required this.notifier});

  final int gameId;
  final CompositionDraft draft;
  final CompositionEditor notifier;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        16,
        AppSpacing.screen,
        AppSpacing.screen,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${draft.assignedCount} rôles pour ${draft.playerCount} joueurs',
                style: typography.counter.copyWith(color: colors.textTertiary),
              ),
              if (draft.remaining == 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: [
                    Icon(AppIcons.compositionComplete, size: 13, color: colors.successText),
                    Text(
                      'Compo complète',
                      style: typography.counter.copyWith(color: colors.successText),
                    ),
                  ],
                ),
            ],
          ),
          AppButton(
            label: 'Lancer la partie',
            onPressed: draft.isValid
                ? () async {
                    await notifier.commit();
                    if (context.mounted) context.go('/');
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
