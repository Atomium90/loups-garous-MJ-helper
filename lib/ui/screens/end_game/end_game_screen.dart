import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../../data/models/game_winner.dart';
import '../../../state/providers/game_list_provider.dart';
import '../../../state/providers/game_provider.dart';
import '../../../state/providers/game_repository_provider.dart';
import '../../../state/session/game_session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../utils/l10n.dart';
import '../../utils/labels.dart';

/// The end-of-game screen: the MJ declares the winner and closes the game. The
/// app never decides this itself - the count is a signal, not a verdict.
class EndGameScreen extends ConsumerStatefulWidget {
  const EndGameScreen({required this.gameId, super.key});

  final int gameId;

  @override
  ConsumerState<EndGameScreen> createState() => _EndGameScreenState();
}

class _EndGameScreenState extends ConsumerState<EndGameScreen> {
  GameWinner? _winner;
  bool _saving = false;

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/games/${widget.gameId}/game');
    }
  }

  Future<void> _confirm() async {
    final winner = _winner;
    if (winner == null || _saving) return;
    setState(() => _saving = true);
    final router = GoRouter.of(context);
    await ref.read(gameRepositoryProvider).endGame(gameId: widget.gameId, winner: winner);
    ref.invalidate(gameListProvider);
    ref.invalidate(gameProvider(widget.gameId));
    router.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final game = ref.watch(gameProvider(widget.gameId)).value;
    final session = ref.watch(gameSessionProvider(widget.gameId)).value;

    // The two counters the MJ weighs the end on: the wolves' side, and everyone else.
    final wolves = session?.engine.aliveWolves(RoleRegistry.all) ?? 0;
    final village = (session?.engine.alivePlayers.length ?? 0) - wolves;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 24, AppSpacing.screen, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(AppIcons.back, size: 18, color: colors.textSecondary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                    onPressed: _back,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.endGameTitle,
                          style: typography.screenTitle.copyWith(color: colors.textPrimary),
                        ),
                        if (game != null)
                          Text(
                            gameTitle(context.l10n, game),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: typography.meta.copyWith(color: colors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, AppSpacing.screen),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.bgInset,
                      borderRadius: BorderRadius.circular(AppRadii.cardSmall),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.endGameAliveCount(wolves, village),
                          style: typography.body.copyWith(color: colors.textPrimary, height: 1.55),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.endGameJudge,
                          style: typography.meta.copyWith(color: colors.textTertiary, height: 1.55),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    context.l10n.endGameWho,
                    style: typography.meta.copyWith(color: colors.textTertiary),
                  ),
                  const SizedBox(height: 10),
                  for (final w in GameWinner.values.where(
                    (w) => w.requiredRoleId == null || (session?.composition[w.requiredRoleId] ?? 0) > 0,
                  ))
                    _WinnerRow(
                      winner: w,
                      selected: w == _winner,
                      onTap: () => setState(() => _winner = w),
                    ),
                ],
              ),
            ),
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
                    label: _winner == null
                        ? context.l10n.endGamePickWinner
                        : context.l10n.endGameTitle,
                    onPressed: _winner == null || _saving ? null : _confirm,
                  ),
                  AppButton(
                    label: context.l10n.endGameKeepPlaying,
                    variant: AppButtonVariant.secondary,
                    onPressed: _back,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WinnerRow extends StatelessWidget {
  const _WinnerRow({required this.winner, required this.selected, required this.onTap});

  final GameWinner winner;
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? colors.accentBg : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.button),
          border: Border.all(color: selected ? colors.accentBorder : colors.borderHairline),
        ),
        child: Row(
          spacing: 12,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: selected ? colors.bgScreen : colors.bgInset,
                shape: BoxShape.circle,
              ),
              child: Icon(
                winnerIcon(winner),
                size: 17,
                color: selected ? colors.accentText : colors.textSecondary,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    winnerLabel(context.l10n, winner),
                    style: typography.rowLabel.copyWith(
                      color: selected ? colors.accentText : colors.textPrimary,
                    ),
                  ),
                  if (winner == GameWinner.none)
                    Text(
                      context.l10n.endGameCancelled,
                      style: typography.counter.copyWith(color: colors.textTertiary),
                    ),
                ],
              ),
            ),
            Icon(
              selected ? AppIcons.winnerPicked : AppIcons.winnerUnpicked,
              size: 19,
              color: selected ? colors.accentBorder : colors.borderControl,
            ),
          ],
        ),
      ),
    );
  }
}
