import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/state/providers/game_repository_provider.dart';
import 'package:loup_garou_mj/ui/screens/before_night/before_night_screen.dart';
import 'package:loup_garou_mj/ui/screens/composition/composition_screen.dart';
import 'package:loup_garou_mj/ui/screens/home/home_screen.dart';
import 'package:loup_garou_mj/ui/screens/players/players_screen.dart';
import 'package:loup_garou_mj/ui/screens/settings/boxes_screen.dart';

import '../../support/fake_game_repository.dart';
import '../../support/pump_app.dart';

const _en = Locale('en');

/// The screens of the game setup, in English: a smoke test that nothing is left in French.
void main() {
  late FakeGameRepository repo;

  setUp(() => repo = FakeGameRepository());

  /// Shows [screen] in English on the fake repository, once it has settled.
  Future<void> pumpEnglish(WidgetTester tester, Widget screen) async {
    await pumpScreen(
      tester,
      screen,
      overrides: [gameRepositoryProvider.overrideWithValue(repo)],
      locale: _en,
    );
    await tester.pumpAndSettle();
  }

  Future<void> bigSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('Accueil with no game', (tester) async {
    await pumpEnglish(tester, const HomeScreen());

    expect(find.text('My games'), findsOneWidget);
    expect(find.text('No games'), findsOneWidget);
    expect(find.text('New game'), findsOneWidget);
    expect(find.text('Mes parties'), findsNothing);
  });

  testWidgets('Accueil lists a draft with its step', (tester) async {
    await repo.createGame(initialPlayerCount: 8);

    await pumpEnglish(tester, const HomeScreen());

    expect(find.text('DRAFTS'), findsOneWidget);
    expect(find.text('Composition to do'), findsOneWidget);
  });

  testWidgets('Composition', (tester) async {
    await bigSurface(tester);
    final id = await repo.createGame(initialPlayerCount: 8);

    await pumpEnglish(tester, CompositionScreen(gameId: id));

    expect(find.text('8 players'), findsOneWidget);
    expect(find.text('0 roles for 8 players'), findsOneWidget);
    expect(find.text('Wolves'), findsOneWidget);
    expect(find.text('Seer'), findsOneWidget);
    expect(find.text('Start the game'), findsOneWidget);
  });

  testWidgets('Players', (tester) async {
    await bigSurface(tester);
    final id = await repo.createGame(initialPlayerCount: 3);
    await repo.saveComposition(gameId: id, playerCount: 3, roleCounts: const {});

    await pumpEnglish(tester, PlayersScreen(gameId: id));

    expect(find.text('0 of 3 named'), findsOneWidget);
    expect(find.text('Player 1'), findsOneWidget);
    expect(find.text('Regulars list'), findsOneWidget);
    expect(find.text('soon'), findsOneWidget);
  });

  testWidgets('Before night 1, with the Thief reserve', (tester) async {
    await bigSurface(tester);
    final id = await repo.createGame(initialPlayerCount: 8);
    await repo.saveComposition(
      gameId: id,
      playerCount: 8,
      roleCounts: const {'voleur': 1, 'loup_garou': 2, 'villageois': 5},
      reserveRoleIds: const ['voyante', 'chasseur'],
    );
    await repo.savePlayerNames(gameId: id, names: [for (var i = 1; i <= 8; i++) 'P$i']);

    await pumpEnglish(tester, BeforeNightScreen(gameId: id));

    expect(find.text('Before night 1'), findsOneWidget);
    expect(find.text('Start night 1'), findsOneWidget);
    expect(find.text("Thief's reserve"), findsOneWidget);
    expect(find.textContaining('face down'), findsOneWidget);
  });

  testWidgets('My boxes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpEnglish(tester, const BoxesScreen());

    expect(find.text('My boxes'), findsOneWidget);
    expect(find.text('8 roles available for your games'), findsOneWidget);
    expect(find.text('The Werewolves of Millers Hollow'), findsOneWidget);
    expect(find.text('Base box · 8 roles supported'), findsOneWidget);
    // The compilations and Characters already hold base roles the app runs (Characters:
    // extra Werewolves); the sticker boxes hold none yet.
    expect(find.text('Compilation · 20 roles supported'), findsOneWidget);
    expect(find.text('Compilation · 19 roles supported'), findsOneWidget);
    expect(find.text('Expansion · 11 roles supported'), findsOneWidget);
    expect(find.text('Stickers · 2 roles supported'), findsOneWidget); // New Moon: Elder, Piper
    expect(find.text('Stickers · roles coming soon'), findsOneWidget); // The Village
  });
}
