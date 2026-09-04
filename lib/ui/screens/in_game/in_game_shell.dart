import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../../state/providers/game_provider.dart';
import '../../../state/session/game_session.dart';
import '../../../state/settings/settings_providers.dart';
import '../../../state/settings/wakelock_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../utils/french_date_format.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/game_tab_bar.dart';
import 'journal_tab.dart';
import 'script_tab.dart';
import 'village_tab.dart';
import 'widgets/aide_memoire_sheet.dart';

/// The container for a running game: a persistent 46px header, then an
/// [IndexedStack] of the three tabs (Script / Village / Journal) with the
/// bottom bar. The tabs are not routed - switching is local state, and each is
/// kept alive so returning to a tab shows exactly what it showed before. The
/// Script tab's own progress is driven by the persisted [GameSession] cursor,
/// not by navigation.
class InGameShell extends ConsumerStatefulWidget {
  const InGameShell({required this.gameId, super.key});

  final int gameId;

  @override
  ConsumerState<InGameShell> createState() => _InGameShellState();
}

class _InGameShellState extends ConsumerState<InGameShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    // Keeps the screen awake while this shell is on screen (respects the toggle).
    ref.watch(wakelockControllerProvider);

    final session = ref.watch(gameSessionProvider(widget.gameId)).value;
    final game = ref.watch(gameProvider(widget.gameId)).value;
    final aideMemoireOn =
        ref.watch(settingsProvider).value?.aideMemoireInScript ?? true;

    final gameName = game?.name ??
        (game != null ? 'Partie du ${frenchDayMonthLabel(game.createdAt)}' : 'Partie');

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _InGameHeader(
              gameName: gameName,
              // help lives on the Script tab only, and can be hidden in Réglages
              showHelp: _index == 0 && aideMemoireOn,
              onHelp: session == null
                  ? null
                  : () => showAideMemoireSheet(context, session.composition),
              onExit: () => context.go('/'),
              onSettings: () => context.push('/settings'),
            ),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: [
                  ScriptTab(gameId: widget.gameId),
                  VillageTab(gameId: widget.gameId),
                  JournalTab(gameId: widget.gameId),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: GameTabBar(
          currentIndex: _index,
          scriptIsNight: session?.engine.phase != GamePhase.day,
          onTap: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}

/// The 46px bar above the tabs: a home pill on the left that leaves the game
/// running and returns to Accueil, `help` (Script tab) + `settings` on the
/// right. Never on a modal sheet.
class _InGameHeader extends StatelessWidget {
  const _InGameHeader({
    required this.gameName,
    required this.showHelp,
    required this.onHelp,
    required this.onExit,
    required this.onSettings,
  });

  final String gameName;
  final bool showHelp;
  final VoidCallback? onHelp;
  final VoidCallback onExit;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 46,
      padding: const EdgeInsets.fromLTRB(12, 0, 16, 0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.borderHairline)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Material(
              color: colors.bgInset,
              borderRadius: BorderRadius.circular(AppRadii.button),
              child: InkWell(
                onTap: onExit,
                borderRadius: BorderRadius.circular(AppRadii.button),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 7,
                    children: [
                      Icon(AppIcons.exitGame, size: 16, color: colors.textSecondary),
                      Flexible(
                        child: Text(
                          gameName,
                          overflow: TextOverflow.ellipsis,
                          style: context.typography.chipLabel.copyWith(
                            fontSize: 13,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Row(
            spacing: 6,
            children: [
              if (showHelp)
                AppIconButton(
                  icon: AppIcons.help,
                  size: AppSizes.iconButtonDense,
                  onTap: onHelp,
                ),
              AppIconButton(
                icon: AppIcons.settings,
                size: AppSizes.iconButtonDense,
                onTap: onSettings,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
