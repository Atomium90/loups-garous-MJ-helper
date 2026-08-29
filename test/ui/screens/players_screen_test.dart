import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/state/providers/game_repository_provider.dart';
import 'package:loup_garou_mj/ui/screens/before_night/before_night_screen.dart';
import 'package:loup_garou_mj/ui/screens/home/home_screen.dart';
import 'package:loup_garou_mj/ui/screens/players/players_screen.dart';
import 'package:loup_garou_mj/ui/theme/app_icons.dart';
import 'package:loup_garou_mj/ui/widgets/app_button.dart';

import '../../support/fake_game_repository.dart';
import '../../support/pump_app.dart';

/// A game with a saved composition and a blank roster of [size] seats.
Future<int> _gameWithBlankRoster(FakeGameRepository repo, int size) async {
  final id = await repo.createGame(initialPlayerCount: size);
  await repo.saveComposition(gameId: id, playerCount: size, roleCounts: const {});
  return id;
}

AppButton _continueButton(WidgetTester tester) =>
    tester.widget<AppButton>(find.widgetWithText(AppButton, 'Continuer'));

void main() {
  testWidgets('renders one field per seat and the "0 sur N nommés" counter', (tester) async {
    final repository = FakeGameRepository();
    final id = await _gameWithBlankRoster(repository, 3);

    await pumpScreen(
      tester,
      PlayersScreen(gameId: id),
      overrides: [gameRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.text('0 sur 3 nommés'), findsOneWidget);
    expect(find.text("Carnet d'habitués"), findsOneWidget);
    expect(find.text('bientôt'), findsOneWidget);
  });

  testWidgets('the counter tracks filled fields; Continuer is inert until all are named', (
    tester,
  ) async {
    final repository = FakeGameRepository();
    final id = await _gameWithBlankRoster(repository, 2);

    await pumpScreen(
      tester,
      PlayersScreen(gameId: id),
      overrides: [gameRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    expect(_continueButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField).at(0), 'Camille');
    await tester.pump();
    expect(find.text('1 sur 2 nommés'), findsOneWidget);
    expect(_continueButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField).at(1), 'Julien');
    await tester.pump();
    expect(find.text('2 sur 2 nommés'), findsOneWidget);
    expect(_continueButton(tester).onPressed, isNotNull);
  });

  testWidgets('a whitespace-only field does not count as named', (tester) async {
    final repository = FakeGameRepository();
    final id = await _gameWithBlankRoster(repository, 1);

    await pumpScreen(
      tester,
      PlayersScreen(gameId: id),
      overrides: [gameRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.pump();
    expect(find.text('0 sur 1 nommés'), findsOneWidget);
    expect(_continueButton(tester).onPressed, isNull);
  });

  testWidgets('Continuer persists trimmed names and pushes A2', (tester) async {
    final repository = FakeGameRepository();
    final id = await _gameWithBlankRoster(repository, 2);

    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(repository)],
      initialLocation: '/games/$id/players',
    );
    await tester.pumpAndSettle();
    expect(find.byType(PlayersScreen), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '  Lina  ');
    await tester.enterText(find.byType(TextField).at(1), 'Théo');
    await tester.pump();

    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    expect(repository.rosterOf(id).map((p) => p.name), ['Lina', 'Théo']);
    expect(find.byType(BeforeNightScreen), findsOneWidget);
  });

  testWidgets('back chevron returns home without starting the game', (tester) async {
    final repository = FakeGameRepository();
    final id = await _gameWithBlankRoster(repository, 2);

    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(repository)],
      initialLocation: '/games/$id/players',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(AppIcons.back).first);
    await tester.pumpAndSettle();

    expect(find.byType(PlayersScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
