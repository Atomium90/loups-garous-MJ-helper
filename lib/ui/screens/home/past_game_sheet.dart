import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../../data/database/app_database.dart';
import '../../../data/models/game_winner.dart';
import '../../../state/providers/game_repository_provider.dart';
import '../../../state/providers/roster_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../utils/l10n.dart';
import '../../utils/labels.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/player_avatar.dart';
import '../in_game/journal_share.dart';
import 'delete_game_sheet.dart';

/// Reopening a finished game: the winner, the run's length, and who was still
/// standing (survivors' roles only - a finished game legitimately has gaps).
Future<void> showPastGameSheet(BuildContext context, Game game) {
  return showAppSheet<void>(context, builder: (_) => _PastGameSheet(game: game));
}

class _PastGameSheet extends ConsumerWidget {
  const _PastGameSheet({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typography = context.typography;
    final registry = RoleRegistry.all;

    final engine = _decodeEngine(game.sessionJson);
    final roster = ref.watch(rosterProvider(game.id)).value ?? const [];
    final roleOf = {for (final r in roster) '${r.id}': r.roleId};

    final players = engine?.players ?? const <Player>[];
    final survivors = players.where((p) => p.alive).toList(growable: false);
    final nights = engine?.nightIndex ?? 0;
    final days = engine == null
        ? 0
        : (engine.phase == GamePhase.day ? engine.nightIndex : engine.nightIndex - 1);
    final winner = game.winner ?? GameWinner.none;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 12, AppSpacing.screen, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gameTitle(context.l10n, game),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.rowLabel.copyWith(fontSize: 17, color: colors.textPrimary),
                      ),
                      Text(
                        context.l10n.dayMonthLabel(game.endedAt ?? game.createdAt),
                        style: typography.meta.copyWith(color: colors.textTertiary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 19, color: colors.textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: colors.bgInset,
                borderRadius: BorderRadius.circular(AppRadii.cardSmall),
              ),
              child: Row(
                spacing: 11,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: colors.bgScreen, shape: BoxShape.circle),
                    child: Icon(winnerIcon(winner), size: 17, color: colors.textPrimary),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.pastWinners,
                        style: typography.counter.copyWith(color: colors.textTertiary),
                      ),
                      Text(
                        winnerLabel(context.l10n, winner),
                        style: typography.rowLabel.copyWith(fontSize: 15, color: colors.textPrimary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              spacing: 20,
              children: [
                _Stat(value: players.length, unit: context.l10n.unitPlayers(players.length)),
                _Stat(value: nights, unit: context.l10n.unitNights(nights)),
                _Stat(value: days, unit: context.l10n.unitDays(days)),
              ],
            ),
            const SizedBox(height: 12),
            Text(context.l10n.pastDeck, style: typography.meta.copyWith(color: colors.textTertiary)),
            const SizedBox(height: 4),
            Text(
              deckLine(context.l10n, game.compositionJson ?? const {}, registry),
              style: typography.meta.copyWith(color: colors.textSecondary, height: 1.7),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.pastSurvivors,
                  style: typography.meta.copyWith(color: colors.textTertiary),
                ),
                Text(
                  context.l10n.pastSurvivorsCount(survivors.length, players.length),
                  style: typography.counter.copyWith(color: colors.textTertiary),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final p in survivors)
                      _SurvivorRow(name: p.name, roleId: roleOf[p.id]),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                context.l10n.pastHiddenRoles(players.length - survivors.length),
                style: typography.counter.copyWith(color: colors.textTertiary, height: 1.5),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.borderHairline)),
              ),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/games/${game.id}/journal');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(
                    spacing: 10,
                    children: [
                      Icon(AppIcons.journal, size: 15, color: colors.textSecondary),
                      Expanded(
                        child: Text(
                          context.l10n.pastFullJournal,
                          style: typography.body.copyWith(color: colors.accentText),
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 16, color: colors.accentText),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              spacing: 8,
              children: [
                Expanded(
                  child: AppButton(
                    label: context.l10n.pastReplay,
                    leadingIcon: AppIcons.replay,
                    onPressed: () => _replay(context, ref),
                  ),
                ),
                SizedBox(
                  width: 46,
                  child: AppButton(
                    label: '',
                    leadingIcon: AppIcons.share,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => shareJournal(context, ref, game),
                  ),
                ),
                SizedBox(
                  width: 46,
                  child: AppButton(
                    label: '',
                    leadingIcon: AppIcons.delete,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _delete(context, ref),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Deletes the game after confirmation, then closes this recap, which no longer has a game.
  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final deleted = await showDeleteGameSheet(context, ref, game);
    if (deleted && context.mounted) Navigator.of(context).pop();
  }

  Future<void> _replay(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.of(context);
    final repo = ref.read(gameRepositoryProvider);
    final newId = await repo.createGame(initialPlayerCount: game.playerCount);
    await repo.saveComposition(
      gameId: newId,
      playerCount: game.playerCount,
      roleCounts: game.compositionJson ?? const {},
    );
    final oldRoster = await repo.getRoster(game.id);
    await repo.savePlayerNames(
      gameId: newId,
      names: [for (final r in oldRoster) r.name],
    );
    router.go('/games/$newId/before-night');
  }
}

/// Null when there is no saved state or it can't be read: the sheet then still shows the
/// winner, the date and the composition, just without the run's length and survivors.
GameState? _decodeEngine(String? sessionJson) {
  if (sessionJson == null) return null;
  try {
    final decoded = jsonDecode(sessionJson) as Map<String, dynamic>;
    return GameStateJson.decode(decoded['engine'] as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.unit});

  final int value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      spacing: 5,
      children: [
        Text(
          '$value',
          style: typography.rowLabel.copyWith(fontSize: 18, color: context.colors.textPrimary),
        ),
        Text(unit, style: typography.counter.copyWith(color: context.colors.textTertiary)),
      ],
    );
  }
}

class _SurvivorRow extends StatelessWidget {
  const _SurvivorRow({required this.name, required this.roleId});

  final String name;
  final String? roleId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final id = roleId;
    final wolves = id != null && RoleRegistry.all.byIdOrNull(id)?.team == Team.werewolves;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.borderHairline)),
      ),
      child: Row(
        spacing: 10,
        children: [
          PlayerAvatar(name: name, size: AppSizes.avatarDense),
          Expanded(
            child: Text(name, style: typography.body.copyWith(color: colors.textPrimary)),
          ),
          Text(
            // An unknown id falls back to the neutral "unknown role" name.
            context.l10n.roleName(id ?? ''),
            style: typography.counter.copyWith(
              color: wolves ? colors.accentText : colors.textSecondary,
              fontWeight: wolves ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
