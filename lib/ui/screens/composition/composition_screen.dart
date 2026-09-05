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
import '../../utils/french_role_label.dart';
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
                _SuggestionCard(draft: draft, notifier: notifier),
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
                if (draft.hasVoleur) ...[
                  const SizedBox(height: 18),
                  _ReserveSection(draft: draft, notifier: notifier),
                ],
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

/// The advisor's pick for the current player count. Hidden once nothing's left to apply -
/// either the draft already matches it, or no suggestion has been computed yet.
class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.draft, required this.notifier});

  final CompositionDraft draft;
  final CompositionEditor notifier;

  @override
  Widget build(BuildContext context) {
    final suggestion = draft.suggestion;
    if (suggestion == null || draft.suggestionApplied) return const SizedBox.shrink();

    final colors = context.colors;
    final typography = context.typography;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.accentBg,
        borderRadius: BorderRadius.circular(AppRadii.button),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(AppIcons.suggestion, size: 18, color: colors.accentText),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Suggestion pour ${draft.playerCount} joueurs',
                      style: typography.rowLabel.copyWith(color: colors.accentText),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      frenchDeckLine(suggestion.roleCounts, RoleRegistry.base),
                      style: typography.counter.copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SuggestionApplyButton(onTap: notifier.applySuggestion),
        ],
      ),
    );
  }
}

/// The small white pill CTA inside the (accent-tinted) suggestion card - `AppButton` doesn't
/// fit here, it's always full-width.
class _SuggestionApplyButton extends StatelessWidget {
  const _SuggestionApplyButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Material(
      color: colors.bgScreen,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.button),
        side: BorderSide(color: colors.borderControl),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.button),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            'Utiliser cette compo',
            style: typography.chipLabel.copyWith(color: colors.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _RoleGroup extends StatelessWidget {
  const _RoleGroup({required this.roles, required this.draft, required this.notifier});

  final List<Role> roles;
  final CompositionDraft draft;
  final CompositionEditor notifier;

  int _scalingMax(Role role) {
    final current = draft.roleCounts[role.id] ?? 0;
    final boxFree = draft.cardsLeft(role.id, RoleRegistry.base) + current;
    return boxFree < draft.playerCount ? boxFree : draft.playerCount;
  }

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
                  // Capped by the table size and by the box cards still free
                  // (4 wolves / 13 villagers, minus any set aside as reserve).
                  max: _scalingMax(role),
                  onChanged: (count) => notifier.setRoleCount(role.id, count),
                )
              : _SingletonRoleChip(role: role, draft: draft, notifier: notifier),
      ],
    );
  }
}

/// A tap-to-toggle chip for the singleton roles. Disabled (dimmed, "en
/// réserve") when the role isn't in the deal and its only box card is already
/// set aside as the Voleur's reserve - the MJ frees it by clearing that
/// reserve slot below.
class _SingletonRoleChip extends StatelessWidget {
  const _SingletonRoleChip({required this.role, required this.draft, required this.notifier});

  final Role role;
  final CompositionDraft draft;
  final CompositionEditor notifier;

  @override
  Widget build(BuildContext context) {
    final inDeal = draft.roleCounts.containsKey(role.id);
    final claimedByReserve =
        !inDeal && draft.cardsLeft(role.id, RoleRegistry.base) <= 0;
    return AppChip(
      label: role.name,
      selected: inDeal,
      enabled: !claimedByReserve,
      note: claimedByReserve ? 'en réserve' : null,
      onTap: () => notifier.toggleRole(role.id),
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

/// The Voleur's two undealt cards. Shown only when the Voleur is in the
/// composition; the MJ picks two roles (any base role) that get set aside on
/// the table and offered to the Voleur when he wakes.
class _ReserveSection extends StatelessWidget {
  const _ReserveSection({required this.draft, required this.notifier});

  final CompositionDraft draft;
  final CompositionEditor notifier;

  Future<void> _pick(BuildContext context, int slot) async {
    final roleId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.colors.bgScreen,
      builder: (_) => _RolePickerSheet(
        roles: draft.availableReserveRoles(slot, RoleRegistry.base),
      ),
    );
    if (roleId != null) notifier.setReserveRole(slot, roleId);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Réserve du Voleur',
          style: typography.meta.copyWith(color: colors.textTertiary),
        ),
        const SizedBox(height: 4),
        Text(
          'Deux cartes en plus des joueurs, posées au centre. Le Voleur pourra en '
          'prendre une à la place de la sienne.',
          style: typography.counter.copyWith(color: colors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 10),
        for (var slot = 0; slot < 2; slot++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ReserveSlot(
              index: slot,
              roleId: slot < draft.reserveRoleIds.length ? draft.reserveRoleIds[slot] : null,
              onTap: () => _pick(context, slot),
              onClear: slot < draft.reserveRoleIds.length
                  ? () => notifier.clearReserveRole(slot)
                  : null,
            ),
          ),
      ],
    );
  }
}

class _ReserveSlot extends StatelessWidget {
  const _ReserveSlot({
    required this.index,
    required this.roleId,
    required this.onTap,
    required this.onClear,
  });

  final int index;
  final String? roleId;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final filled = roleId != null;
    return Material(
      color: filled ? colors.accentBg : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.button),
        side: BorderSide(color: filled ? colors.accentBorder : colors.borderControl),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.button),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Text(
                'Carte ${index + 1}',
                style: typography.counter.copyWith(color: colors.textTertiary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  filled ? RoleRegistry.base.byId(roleId!).name : 'Choisir une carte',
                  style: typography.rowLabel.copyWith(
                    color: filled ? colors.accentText : colors.textSecondary,
                  ),
                ),
              ),
              if (onClear != null)
                GestureDetector(
                  onTap: onClear,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(AppIcons.removeReserve, size: 16, color: colors.accentText),
                  ),
                )
              else
                Icon(AppIcons.newGame, size: 15, color: colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _RolePickerSheet extends StatelessWidget {
  const _RolePickerSheet({required this.roles});

  final List<Role> roles;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, 8),
            child: Text(
              'Quelle carte ?',
              style: typography.rowLabel.copyWith(color: colors.textPrimary),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final role in roles)
                  ListTile(
                    title: Text(
                      role.name,
                      style: typography.body.copyWith(color: colors.textPrimary),
                    ),
                    onTap: () => Navigator.of(context).pop(role.id),
                  ),
              ],
            ),
          ),
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
              if (draft.remaining == 0 && draft.reserveComplete)
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
          if (draft.hasVoleur && !draft.reserveComplete)
            Text(
              'Choisissez les 2 cartes de réserve du Voleur',
              style: typography.counter.copyWith(color: colors.warnText),
            ),
          AppButton(
            label: 'Lancer la partie',
            onPressed: draft.isValid
                ? () async {
                    // Capture the router before the await: commit() invalidates
                    // gameListProvider/gameProvider, which can rebuild this subtree
                    // (see flutter_ui_gotchas #1).
                    final router = GoRouter.of(context);
                    await notifier.commit();
                    router.go('/games/$gameId/players');
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
