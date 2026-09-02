import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../state/providers/game_provider.dart';
import '../../../state/providers/night_log_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../utils/french_date_format.dart';

/// The Journal tab: every logged line, grouped under its uppercase phase
/// header, most recent first.
class JournalTab extends ConsumerWidget {
  const JournalTab({required this.gameId, super.key});

  final int gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typography = context.typography;
    final logAsync = ref.watch(nightLogProvider(gameId));
    final game = ref.watch(gameProvider(gameId)).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 24, AppSpacing.screen, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Journal', style: typography.screenTitle.copyWith(color: colors.textPrimary)),
              if (game != null)
                Text(
                  game.name ?? 'Partie du ${frenchDayMonthLabel(game.createdAt)}',
                  style: typography.meta.copyWith(color: colors.textSecondary),
                ),
            ],
          ),
        ),
        Expanded(
          child: logAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => _centered(context, 'Impossible de charger le journal.'),
            data: (rows) => rows.isEmpty
                ? _centered(context, "Rien à consigner pour l'instant.")
                : _JournalList(rows: rows),
          ),
        ),
      ],
    );
  }

  Widget _centered(BuildContext context, String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.screen),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: context.typography.body.copyWith(color: context.colors.textSecondary),
      ),
    ),
  );
}

class _JournalList extends StatelessWidget {
  const _JournalList({required this.rows});

  final List<NightLogRow> rows;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    // rows are already newest-first; emit a header each time the phase changes.
    final children = <Widget>[];
    String? lastPhase;
    for (final row in rows) {
      if (row.phaseLabel != lastPhase) {
        lastPhase = row.phaseLabel;
        children.add(
          Padding(
            padding: EdgeInsets.only(top: children.isEmpty ? 0 : 14, bottom: 6),
            child: Text(
              row.phaseLabel,
              style: typography.sectionLabel.copyWith(color: colors.textTertiary),
            ),
          ),
        );
      }
      final icon = AppIcons.nightLog(row.iconName);
      children.add(
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.borderHairline)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Icon(icon ?? AppIcons.journal, size: 15, color: colors.textTertiary),
              Expanded(
                child: Text(
                  row.line,
                  style: typography.body.copyWith(color: colors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 14, AppSpacing.screen, 20),
      children: children,
    );
  }
}
