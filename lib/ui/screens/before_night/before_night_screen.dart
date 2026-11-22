import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../../data/database/app_database.dart';
import '../../../state/providers/game_provider.dart';
import '../../../state/providers/game_repository_provider.dart';
import '../../../state/providers/roster_provider.dart';
import '../../../state/session/night_script.dart';
import '../../../state/settings/settings_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../widgets/setup_header.dart';
import '../../utils/l10n.dart';
import '../../utils/labels.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/player_avatar.dart';
import 'deal_role_sheet.dart';

/// "Avant la nuit 1". The MJ shuffles and deals the physical cards. The roster already exists
/// (names, no roles). Blind by default: the app learns the roles as each one wakes. When the
/// settings and the composition call for it, the MJ can note each player's card here instead,
/// fully or in part. "Commencer la nuit 1" is what finally moves the game to
/// GameStatus.inProgress.
class BeforeNightScreen extends ConsumerWidget {
  const BeforeNightScreen({required this.gameId, super.key});

  final int gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameAsync = ref.watch(gameProvider(gameId));
    final rosterAsync = ref.watch(rosterProvider(gameId));

    Widget centered(String message) => Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: context.typography.body.copyWith(color: context.colors.textSecondary),
        ),
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: switch ((gameAsync, rosterAsync)) {
          _ when gameAsync.isLoading || rosterAsync.isLoading =>
            const Center(child: CircularProgressIndicator()),
          _ when gameAsync.hasError || rosterAsync.hasError =>
            centered(context.l10n.gameLoadError),
          (AsyncData(value: final game), AsyncData(value: final roster)) =>
            game == null
                ? centered(context.l10n.gameLoadError)
                : _Body(gameId: gameId, game: game, roster: roster),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.gameId, required this.game, required this.roster});

  final int gameId;
  final Game game;
  final List<PlayerRow> roster;

  Future<void> _onStart(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.of(context);
    await ref.read(gameRepositoryProvider).startGame(gameId);
    // Into the running-game shell; GameSession seeds the night-1 snapshot lazily on first read.
    router.go('/games/$gameId/game');
  }

  /// Asks which card [player] was dealt and writes it onto the roster.
  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    PlayerRow player,
    String name,
    List<({String roleId, int count})> pack,
  ) async {
    // The player's own card counts as free, so it can be changed.
    final options = cardsLeftIn(pack, [
      for (final other in roster)
        if (other.id != player.id) other.roleId,
    ]);
    final choice = await showAppSheet<DealRoleChoice>(
      context,
      builder: (_) => DealRoleSheet(playerName: name, options: options, current: player.roleId),
    );
    if (choice == null || !context.mounted) return;
    await ref.read(gameRepositoryProvider).assignRoles(
      playerRowIds: [player.id],
      roleId: choice.roleId,
    );
    ref.invalidate(rosterProvider(gameId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final composition = game.compositionJson ?? const <String, int>{};
    final reserve = game.reserveRolesJson ?? const <String>[];
    // A Voleur with no reserve picked: the reserve is drawn, from a pack of two more cards.
    final drawnReserve = composition.containsKey('voleur') && reserve.isEmpty;
    // The MJ may note every card at the deal, unless they asked to be spared when the composition
    // does not need it.
    final onlyIfNeeded = ref.watch(settingsProvider).value?.dealNotesOnlyIfNeeded ?? false;
    final noting =
        !onlyIfNeeded ||
        RoleRegistry.all.anyNeedsDealNotes([
          for (final entry in composition.entries)
            if (entry.value > 0) entry.key,
        ]);
    final pack = dealPackOf(composition, reserveDrawn: drawnReserve);
    final deck = deckLine(context.l10n, {
      ...composition,
      if (drawnReserve) 'villageois': (composition['villageois'] ?? 0) + 2,
    }, RoleRegistry.all);

    return Column(
      children: [
        SetupHeader(
          title: context.l10n.beforeNightTitle,
          subtitle: gameTitle(context.l10n, game),
          onBack: () => context.pop(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 14, AppSpacing.screen, 0),
          child: _DealCallout(
            cardCount: game.playerCount,
            hint: noting ? context.l10n.beforeNightNotesHint : context.l10n.beforeNightDealHint,
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LabelRow(
                  left: context.l10n.beforeNightVillage,
                  right: noting
                      ? context.l10n.beforeNightNoted(
                          roster.where((p) => p.roleId != null).length,
                          roster.length,
                        )
                      : context.l10n.beforeNightRolesToDiscover,
                ),
                const SizedBox(height: 8),
                _RosterGrid(
                  roster: roster,
                  onPick: noting ? (player, name) => _pick(context, ref, player, name, pack) : null,
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.beforeNightDeal,
                  style: context.typography.meta.copyWith(color: context.colors.textTertiary),
                ),
                const SizedBox(height: 6),
                Text(
                  deck,
                  style: context.typography.meta.copyWith(
                    color: context.colors.textSecondary,
                    height: 1.7,
                  ),
                ),
                if ((composition['ange'] ?? 0) > 0) ...[
                  const SizedBox(height: 16),
                  _AngelCallout(),
                ],
                if (reserve.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _ReserveCallout(hint: context.l10n.beforeNightReserveHint(reserveLine(context.l10n, reserve))),
                ] else if (drawnReserve) ...[
                  const SizedBox(height: 16),
                  _ReserveCallout(hint: context.l10n.beforeNightPackHint(game.playerCount + 2)),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            16,
            AppSpacing.screen,
            AppSpacing.screen,
          ),
          child: AppButton(
            label: (composition['ange'] ?? 0) > 0
                ? context.l10n.beforeNightStartAngel
                : context.l10n.beforeNightStart,
            leadingIcon: AppIcons.nightStart,
            onPressed: () => _onStart(context, ref),
          ),
        ),
      ],
    );
  }
}


class _DealCallout extends StatelessWidget {
  const _DealCallout({required this.cardCount, required this.hint});

  final int cardCount;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.accentBg,
        borderRadius: BorderRadius.circular(AppRadii.button),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.deal, size: 18, color: colors.accentText),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.beforeNightDealTitle(cardCount),
                  style: typography.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colors.accentText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hint,
                  style: typography.meta.copyWith(color: colors.textSecondary, height: 1.55),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// With the Angel in play the game does not start with the night.
class _AngelCallout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.bgInset,
        borderRadius: BorderRadius.circular(AppRadii.button),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.angel, size: 18, color: colors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.beforeNightAngelHint,
              style: typography.meta.copyWith(color: colors.textSecondary, height: 1.55),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Voleur's two reserve cards: which ones to set aside, or how they come about when they are
/// drawn. The MJ must do it as written, or the physical game and the app diverge.
class _ReserveCallout extends StatelessWidget {
  const _ReserveCallout({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.bgInset,
        borderRadius: BorderRadius.circular(AppRadii.button),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.thief, size: 18, color: colors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.reserveTitle,
                  style: typography.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hint,
                  style: typography.meta.copyWith(color: colors.textSecondary, height: 1.55),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelRow extends StatelessWidget {
  const _LabelRow({required this.left, required this.right});

  final String left;
  final String right;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    final colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(left, style: typography.meta.copyWith(color: colors.textTertiary)),
        Text(right, style: typography.counter.copyWith(color: colors.textTertiary)),
      ],
    );
  }
}

/// One player of the village; tappable, with their card shown under the name, when the cards are
/// noted at the deal.
class _PlayerTile extends StatelessWidget {
  const _PlayerTile({required this.name, required this.roleId, this.onTap});

  final String name;
  final String? roleId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Material(
      color: roleId == null ? colors.bgInset : colors.accentBg,
      borderRadius: BorderRadius.circular(AppRadii.button),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.button),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              PlayerAvatar(name: name, fillColor: colors.bgScreen),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: typography.body.copyWith(color: colors.textPrimary),
                    ),
                    if (roleId != null)
                      Text(
                        context.l10n.roleName(roleId!),
                        overflow: TextOverflow.ellipsis,
                        style: typography.meta.copyWith(color: colors.accentText),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RosterGrid extends StatelessWidget {
  const _RosterGrid({required this.roster, this.onPick});

  final List<PlayerRow> roster;

  /// Called with a player and the name shown for them when the MJ taps them to note their card;
  /// null when the cards are not noted at the deal.
  final void Function(PlayerRow player, String name)? onPick;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;
        final tileWidth = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (i, player) in roster.indexed)
              SizedBox(
                width: tileWidth,
                child: _PlayerTile(
                  name: player.name.isEmpty ? context.l10n.playerHint(i + 1) : player.name,
                  roleId: player.roleId,
                  onTap: onPick == null
                      ? null
                      : () => onPick!(
                          player,
                          player.name.isEmpty ? context.l10n.playerHint(i + 1) : player.name,
                        ),
                ),
              ),
          ],
        );
      },
    );
  }
}
