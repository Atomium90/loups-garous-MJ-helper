import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_icons.dart';
import 'journal_tab.dart';

/// The Journal on its own, with a back chevron - reached from the past-game
/// recap ("Voir le journal complet"), outside the in-game tab shell.
class GameJournalScreen extends StatelessWidget {
  const GameJournalScreen({required this.gameId, super.key});

  final int gameId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 12, AppSpacing.screen, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: Icon(AppIcons.back, size: 18, color: context.colors.textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => context.pop(),
                ),
              ),
            ),
            Expanded(child: JournalTab(gameId: gameId)),
          ],
        ),
      ),
    );
  }
}
