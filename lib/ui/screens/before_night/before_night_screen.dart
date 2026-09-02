import 'package:flutter/material.dart';
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
import '../../utils/french_date_format.dart';
import '../../utils/french_role_label.dart';
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
            centered('Impossible de charger cette partie.'),
          (AsyncData(value: final game), AsyncData(value: final roster)) =>
            game == null
                ? centered('Impossible de charger cette partie.')
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
    final deckLine = frenchDeckLine(composition, RoleRegistry.base);

    return Column(
      children: [
        _Header(subtitle: game.name ?? 'Partie du ${frenchDayMonthLabel(game.createdAt)}'),
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
                _LabelRow(left: 'Le village', right: 'rôles à découvrir'),
                const SizedBox(height: 8),
                _RosterGrid(roster: roster),
                const SizedBox(height: 16),
                Text(
                  'Dans la pioche',
                  style: context.typography.meta.copyWith(color: context.colors.textTertiary),
                ),
                const SizedBox(height: 6),
                Text(
                  deckLine,
                  style: context.typography.meta.copyWith(
                    color: context.colors.textSecondary,
                    height: 1.7,
                  ),
                ),
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
            label: 'Commencer la nuit 1',
            leadingIcon: AppIcons.nightStart,
            onPressed: () => _onStart(context, ref),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
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
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Avant la nuit 1',
                style: typography.screenTitle.copyWith(color: colors.textPrimary),
              ),
              Text(subtitle, style: typography.meta.copyWith(color: colors.textSecondary)),
            ],
          ),
        ],
      ),
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
                  'Distribuez les $cardCount cartes',
                  style: typography.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colors.accentText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "Mélangez et distribuez à l'aveugle. L'app note les rôles au fil de la "
                  'nuit 1, quand chacun se réveille.',
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
                        name: player.name.isEmpty ? 'Joueur ${i + 1}' : player.name,
                        fillColor: colors.bgScreen,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          player.name.isEmpty ? 'Joueur ${i + 1}' : player.name,
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
