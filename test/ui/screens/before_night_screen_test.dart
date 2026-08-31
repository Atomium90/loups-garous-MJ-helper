import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/data/models/game_status.dart';
import 'package:loup_garou_mj/state/providers/game_repository_provider.dart';
import 'package:loup_garou_mj/ui/screens/before_night/before_night_screen.dart';
import 'package:loup_garou_mj/ui/screens/in_game/script_tab.dart';

import '../../support/fake_game_repository.dart';
import '../../support/pump_app.dart';

/// A setup game with the given composition and a fully-named roster.
Future<int> _readyToDeal(
  FakeGameRepository repo, {
  required Map<String, int> composition,
  required List<String> names,
}) async {
  final id = await repo.createGame(initialPlayerCount: names.length);
  await repo.saveComposition(gameId: id, playerCount: names.length, roleCounts: composition);
  await repo.savePlayerNames(gameId: id, names: names);
  return id;
}

void main() {
  testWidgets('shows the roster names and the deck line derived from the composition', (
    tester,
  ) async {
    final repository = FakeGameRepository();
    final id = await _readyToDeal(
      repository,
      composition: const {'loup_garou': 2, 'voyante': 1, 'villageois': 3},
      names: const ['Camille', 'Julien', 'Noa', 'Lina', 'Théo', 'Awa'],
    );

    await pumpScreen(
      tester,
      BeforeNightScreen(gameId: id),
      overrides: [gameRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    expect(find.text('Camille'), findsOneWidget);
    expect(find.text('Awa'), findsOneWidget);
    expect(find.text('Distribuez les 6 cartes'), findsOneWidget);
    expect(find.text('2 Loups-Garous · Voyante · 3 Villageois'), findsOneWidget);
  });

  testWidgets('Commencer la nuit 1 starts the game and opens the Script tab', (tester) async {
    final repository = FakeGameRepository();
    final id = await _readyToDeal(
      repository,
      composition: const {'loup_garou': 1, 'voyante': 1, 'villageois': 1},
      names: const ['Lina', 'Théo', 'Awa'],
    );

    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(repository)],
      initialLocation: '/games/$id/before-night',
    );
    await tester.pumpAndSettle();
    expect(find.byType(BeforeNightScreen), findsOneWidget);

    await tester.tap(find.text('Commencer la nuit 1'));
    await tester.pumpAndSettle();

    expect((await repository.getGame(id))!.status, GameStatus.inProgress);
    expect(find.byType(ScriptTab), findsOneWidget);
    expect(find.text('Nuit 1'), findsOneWidget);
  });
}
