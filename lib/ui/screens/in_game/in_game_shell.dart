import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../../state/session/game_session.dart';
import '../../widgets/game_tab_bar.dart';
import 'journal_tab.dart';
import 'script_tab.dart';
import 'village_tab.dart';

/// The container for a running game: an [IndexedStack] of the three tabs
/// (Script / Village / Journal) with the bottom bar. The tabs are not routed -
/// switching is local state, and each is kept alive so returning to a tab
/// shows exactly what it showed before. The Script tab's own progress is
/// driven by the persisted [GameSession] cursor, not by navigation.
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
    final phase = ref.watch(gameSessionProvider(widget.gameId)).value?.engine.phase;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _index,
          children: [
            ScriptTab(gameId: widget.gameId),
            VillageTab(gameId: widget.gameId),
            JournalTab(gameId: widget.gameId),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: GameTabBar(
          currentIndex: _index,
          scriptIsNight: phase != GamePhase.day,
          onTap: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}
