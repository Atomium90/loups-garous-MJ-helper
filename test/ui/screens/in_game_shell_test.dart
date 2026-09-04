import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/data/models/night_log_entry.dart';
import 'package:loup_garou_mj/state/providers/game_repository_provider.dart';
import 'package:loup_garou_mj/state/session/session_cursor.dart';
import 'package:loup_garou_mj/ui/screens/home/home_screen.dart';
import 'package:loup_garou_mj/ui/screens/in_game/journal_tab.dart';
import 'package:loup_garou_mj/ui/screens/in_game/script_tab.dart';
import 'package:loup_garou_mj/ui/screens/in_game/village_tab.dart';
import 'package:loup_garou_mj/ui/screens/settings/settings_screen.dart';
import 'package:loup_garou_mj/ui/theme/app_icons.dart';
import 'package:rules_engine/rules_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_game_repository.dart';
import '../../support/pump_app.dart';

/// A running game with a seeded night-1 session (Voyante -> Loups -> Sorcière).
Future<int> _runningGame(FakeGameRepository repo) async {
  final id = await repo.createGame(initialPlayerCount: 3);
  await repo.saveComposition(
    gameId: id,
    playerCount: 3,
    roleCounts: const {'loup_garou': 1, 'voyante': 1, 'sorciere': 1},
  );
  await repo.savePlayerNames(gameId: id, names: const ['Ana', 'Bo', 'Cy']);
  await repo.startGame(id);
  final engine = GameState.initial(
    players: const [
      Player(id: '1', name: 'Ana', roleId: 'villageois'),
      Player(id: '2', name: 'Bo', roleId: 'villageois'),
      Player(id: '3', name: 'Cy', roleId: 'villageois'),
    ],
  );
  await repo.saveSession(
    gameId: id,
    sessionJson: jsonEncode({
      'engine': GameStateJson.encode(engine),
      'cursor': SessionCursor.nightStart.toJson(),
    }),
  );
  return id;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the shell shows the three tabs and switches branches', (tester) async {
    final repo = FakeGameRepository();
    final id = await _runningGame(repo);

    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(repo)],
      initialLocation: '/games/$id/game',
    );
    await tester.pumpAndSettle();

    expect(find.byType(ScriptTab), findsOneWidget);
    expect(find.text('Script'), findsOneWidget);
    expect(find.text('Village'), findsOneWidget);
    expect(find.text('Journal'), findsOneWidget);

    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();
    expect(find.byType(JournalTab), findsOneWidget);

    await tester.tap(find.text('Village'));
    await tester.pumpAndSettle();
    expect(find.byType(VillageTab), findsOneWidget);
  });

  testWidgets('the Journal groups lines by phase, newest first', (tester) async {
    final repo = FakeGameRepository();
    final id = await _runningGame(repo);
    await repo.appendNightLog(
      gameId: id,
      entries: const [
        NightLogEntry(phaseLabel: 'NUIT 1', iconName: 'wolves', line: 'Les Loups désignent Bo'),
        NightLogEntry(phaseLabel: 'NUIT 1', iconName: 'flask', line: 'La Sorcière empoisonne Cy'),
      ],
    );

    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(repo)],
      initialLocation: '/games/$id/game',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();

    expect(find.text('NUIT 1'), findsOneWidget);
    expect(find.text('Les Loups désignent Bo'), findsOneWidget);
    expect(find.text('La Sorcière empoisonne Cy'), findsOneWidget);
  });

  testWidgets('Home resume card shows the real step line and opens the Script tab', (
    tester,
  ) async {
    final repo = FakeGameRepository();
    await _runningGame(repo);

    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(repo)],
    );
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    // first night step for this composition is the Voyante
    expect(find.text('Nuit 1 · Voyante'), findsOneWidget);

    await tester.tap(find.text('Nuit 1 · Voyante'));
    await tester.pumpAndSettle();
    expect(find.byType(ScriptTab), findsOneWidget);
  });

  testWidgets('the header home button returns to Accueil, game stays running', (tester) async {
    final repo = FakeGameRepository();
    final id = await _runningGame(repo);

    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(repo)],
      initialLocation: '/games/$id/game',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(AppIcons.exitGame));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect((await repo.getGame(id))!.status.name, 'inProgress');
  });

  testWidgets('the header gear opens Réglages and back returns to the game', (tester) async {
    final repo = FakeGameRepository();
    final id = await _runningGame(repo);

    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(repo)],
      initialLocation: '/games/$id/game',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(AppIcons.settings));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.tap(find.byIcon(AppIcons.back));
    await tester.pumpAndSettle();
    expect(find.byType(ScriptTab), findsOneWidget); // back in the game, not Accueil
  });
}
