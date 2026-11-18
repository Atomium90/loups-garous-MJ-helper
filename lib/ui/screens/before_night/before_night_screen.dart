import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../../data/database/app_database.dart';
import '../../../state/providers/game_provider.dart';
import '../../../state/providers/game_repository_provider.dart';
import '../../../state/providers/roster_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../widgets/setup_header.dart';
import '../../utils/l10n.dart';
import '../../utils/labels.dart';
import '../../widgets/app_button.dart';
import '../../widgets/player_avatar.dart';

/// "Avant la nuit 1". The blind deal: the MJ shuffles and deals the physical cards,
/// nobody knows who has what. The roster already exists (names, no roles); nothing to enter
/// here. "Commencer la nuit 1" is what finally moves the game to GameStatus.inProgress.
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final composition = game.compositionJson ?? const <String, int>{};
    final deck = deckLine(context.l10n, composition, RoleRegistry.base);
    final reserve = game.reserveRolesJson ?? const <String>[];

    return Column(
      children: [
        SetupHeader(
          title: context.l10n.beforeNightTitle,
          subtitle: gameTitle(context.l10n, game),
          onBack: () => context.pop(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 14, AppSpacing.screen, 0),
          child: _DealCallout(cardCount: game.playerCount),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LabelRow(
                  left: context.l10n.beforeNightVillage,
                  right: context.l10n.beforeNightRolesToDiscover,
                ),
                const SizedBox(height: 8),
                _RosterGrid(roster: roster),
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
                if (reserve.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _ReserveCallout(line: reserveLine(context.l10n, reserve)),
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
            label: context.l10n.beforeNightStart,
            leadingIcon: AppIcons.nightStart,
            onPressed: () => _onStart(context, ref),
          ),
        ),
      ],
    );
  }
}


class _DealCallout extends StatelessWidget {
  const _DealCallout({required this.cardCount});

  final int cardCount;

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
                  context.l10n.beforeNightDealHint,
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

/// The Voleur's two reserve cards. The MJ must set aside exactly these on the
/// table, or the physical game and the app diverge.
class _ReserveCallout extends StatelessWidget {
  const _ReserveCallout({required this.line});

  final String line;

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
                  context.l10n.beforeNightReserveHint(line),
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

class _RosterGrid extends StatelessWidget {
  const _RosterGrid({required this.roster});

  final List<PlayerRow> roster;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
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
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.bgInset,
                    borderRadius: BorderRadius.circular(AppRadii.button),
                  ),
                  child: Row(
                    children: [
                      PlayerAvatar(
                        name: player.name.isEmpty ? context.l10n.playerHint(i + 1) : player.name,
                        fillColor: colors.bgScreen,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          player.name.isEmpty ? context.l10n.playerHint(i + 1) : player.name,
                          overflow: TextOverflow.ellipsis,
                          style: context.typography.body.copyWith(color: colors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
