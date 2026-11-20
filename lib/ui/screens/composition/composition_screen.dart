import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../../state/composition/composition_draft.dart';
import '../../../state/composition/composition_editor_notifier.dart';
import '../../../state/settings/settings_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../widgets/setup_header.dart';
import '../../utils/l10n.dart';
import '../../utils/labels.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/app_stepper.dart';

class CompositionScreen extends ConsumerWidget {
  const CompositionScreen({required this.gameId, super.key});

  final int gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftAsync = ref.watch(compositionEditorProvider(gameId));
    final notifier = ref.read(compositionEditorProvider(gameId).notifier);
    final pool = ref.watch(cardPoolProvider);

    return Scaffold(
      body: SafeArea(
        child: draftAsync.when(
          data: (draft) =>
              _CompositionBody(gameId: gameId, draft: draft, notifier: notifier, pool: pool),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screen),
              child: Text(
                context.l10n.gameLoadError,
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
  const _CompositionBody({
    required this.gameId,
    required this.draft,
    required this.notifier,
    required this.pool,
  });

  final int gameId;
  final CompositionDraft draft;
  final CompositionEditor notifier;
  final CardPool pool;

  /// A heading and the chips of [team]'s roles in the pool; nothing when the pool has none.
  List<Widget> _section(BuildContext context, String label, Team team) {
    final roles = pool.available.byTeam(team);
    if (roles.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          label,
          style: context.typography.meta.copyWith(color: context.colors.textTertiary),
        ),
      ),
      _RoleGroup(roles: roles, draft: draft, notifier: notifier, pool: pool),
      const SizedBox(height: 14),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final sections = [
      (context.l10n.compositionVillage, Team.village),
      (context.l10n.compositionWolves, Team.werewolves),
      (context.l10n.compositionSolo, Team.solo),
      (context.l10n.compositionAmbiguous, Team.ambiguous),
    ];

    return Column(
      children: [
        SetupHeader(
          title: context.l10n.compositionTitle,
          subtitle: context.l10n.playerCountLabel(draft.playerCount),
          // Leaving keeps the game as a draft (what was picked is saved as it is edited);
          // only the trash button under Brouillons on Home deletes it.
          onBack: () => context.go('/'),
        ),
        _PlayerCountRow(
          playerCount: draft.playerCount,
          onChanged: notifier.setPlayerCount,
          max: pool.maxPlayers,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SuggestionCard(draft: draft, notifier: notifier, registry: pool.available),
                for (final (label, team) in sections) ..._section(context, label, team),
                if (draft.reserveChosen && draft.hasVoleur) ...[
                  const SizedBox(height: 18),
                  _ReserveSection(draft: draft, notifier: notifier, pool: pool),
                ] else if (draft.reserveDrawn) ...[
                  const SizedBox(height: 4),
                  _DrawnReserveNote(packSize: draft.playerCount + 2),
                ],
              ],
            ),
          ),
        ),
        _Footer(gameId: gameId, draft: draft, notifier: notifier, pool: pool),
      ],
    );
  }
}


class _PlayerCountRow extends StatelessWidget {
  const _PlayerCountRow({required this.playerCount, required this.onChanged, required this.max});

  final int playerCount;
  final ValueChanged<int> onChanged;

  /// The most players the owned boxes seat. A draft saved with more (a box was unticked since)
  /// keeps its count, and can only be brought down.
  final int max;

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
              context.l10n.compositionPlayers,
              style: context.typography.body.copyWith(color: colors.textSecondary),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: AppStepper(
              value: playerCount,
              min: CardPool.minPlayers,
              max: playerCount > max ? playerCount : max,
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
  const _SuggestionCard({required this.draft, required this.notifier, required this.registry});

  final CompositionDraft draft;
  final CompositionEditor notifier;
  final RoleRegistry registry;

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
                      context.l10n.compositionSuggestion(draft.playerCount),
                      style: typography.rowLabel.copyWith(color: colors.accentText),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      deckLine(context.l10n, suggestion.roleCounts, registry),
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
            context.l10n.compositionUseSuggestion,
            style: typography.chipLabel.copyWith(color: colors.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _RoleGroup extends StatelessWidget {
  const _RoleGroup({
    required this.roles,
    required this.draft,
    required this.notifier,
    required this.pool,
  });

  final List<Role> roles;
  final CompositionDraft draft;
  final CompositionEditor notifier;
  final CardPool pool;

  int _scalingMax(Role role) {
    final current = draft.roleCounts[role.id] ?? 0;
    final boxFree = draft.cardsLeft(role.id, pool) + current;
    return boxFree < draft.playerCount ? boxFree : draft.playerCount;
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final role in roles)
          role.multiple
              ? _RoleCountChip(
                  label: context.l10n.roleName(role.id),
                  count: draft.roleCounts[role.id] ?? 0,
                  // Capped by the table size and by the box cards still free
                  // (4 wolves / 13 villagers, minus any set aside as reserve).
                  max: _scalingMax(role),
                  onChanged: (count) => notifier.setRoleCount(role.id, count),
                )
              : _SingletonRoleChip(role: role, draft: draft, notifier: notifier, pool: pool),
      ],
    );
  }
}

/// A tap-to-toggle chip for the roles that take one holder (or one fixed group). Disabled (dimmed, "en
/// réserve") when the role isn't in the deal and its only box card is already
/// set aside as the Voleur's reserve - the MJ frees it by clearing that
/// reserve slot below.
class _SingletonRoleChip extends StatelessWidget {
  const _SingletonRoleChip({
    required this.role,
    required this.draft,
    required this.notifier,
    required this.pool,
  });

  final Role role;
  final CompositionDraft draft;
  final CompositionEditor notifier;
  final CardPool pool;

  @override
  Widget build(BuildContext context) {
    final inDeal = draft.roleCounts.containsKey(role.id);
    final claimedByReserve = !inDeal && draft.cardsLeft(role.id, pool) < role.groupSize;
    return AppChip(
      label: context.l10n.roleName(role.id),
      selected: inDeal,
      enabled: !claimedByReserve,
      note: claimedByReserve ? context.l10n.compositionInReserve : null,
      onTap: () => notifier.toggleRole(role.id),
    );
  }
}

/// A pill combining a role's name with an inline stepper, for the roles that can exceed
/// count 1 (the Loups-Garous, the Simples Villageois) - reuses the one increment/decrement affordance the design
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
  const _ReserveSection({required this.draft, required this.notifier, required this.pool});

  final CompositionDraft draft;
  final CompositionEditor notifier;
  final CardPool pool;

  Future<void> _pick(BuildContext context, int slot) async {
    final roleId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.colors.bgScreen,
      builder: (_) => _RolePickerSheet(
        roles: draft.availableReserveRoles(slot, pool),
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
          context.l10n.reserveTitle,
          style: typography.meta.copyWith(color: colors.textTertiary),
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.reserveExplain,
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

/// What the Voleur adds to the pack when his reserve is left to the draw.
class _DrawnReserveNote extends StatelessWidget {
  const _DrawnReserveNote({required this.packSize});

  final int packSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.bgInset,
        borderRadius: BorderRadius.circular(AppRadii.button),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Icon(AppIcons.thief, size: 18, color: colors.textSecondary),
          Expanded(
            child: Text(
              context.l10n.reserveRandomNote(packSize),
              style: context.typography.meta.copyWith(color: colors.textSecondary, height: 1.55),
            ),
          ),
        ],
      ),
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
                context.l10n.reserveCard(index + 1),
                style: typography.counter.copyWith(color: colors.textTertiary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  filled ? context.l10n.roleName(roleId!) : context.l10n.reservePick,
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
              context.l10n.reserveWhichCard,
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
                      context.l10n.roleName(role.id),
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
  const _Footer({
    required this.gameId,
    required this.draft,
    required this.notifier,
    required this.pool,
  });

  final int gameId;
  final CompositionDraft draft;
  final CompositionEditor notifier;
  final CardPool pool;

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
                context.l10n.compositionRoleCount(draft.assignedCount, draft.playerCount),
                style: typography.counter.copyWith(color: colors.textTertiary),
              ),
              if (draft.remaining == 0 && draft.reserveComplete)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: [
                    Icon(AppIcons.compositionComplete, size: 13, color: colors.successText),
                    Text(
                      context.l10n.compositionComplete,
                      style: typography.counter.copyWith(color: colors.successText),
                    ),
                  ],
                ),
            ],
          ),
          if (draft.hasVoleur && !draft.reserveComplete)
            Text(
              context.l10n.compositionPickReserve,
              style: typography.counter.copyWith(color: colors.warnText),
            ),
          AppButton(
            label: context.l10n.compositionStart,
            onPressed: draft.isValidFor(pool)
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
