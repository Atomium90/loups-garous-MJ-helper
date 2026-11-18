import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/data/database/app_database.dart';
import 'package:loup_garou_mj/data/models/game_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loup_garou_mj/main.dart';
import 'package:loup_garou_mj/state/providers/game_repository_provider.dart';
import 'package:loup_garou_mj/ui/screens/home/home_screen.dart';
import 'package:loup_garou_mj/ui/screens/settings/boxes_screen.dart';
import 'package:loup_garou_mj/ui/screens/settings/settings_screen.dart';
import 'package:loup_garou_mj/ui/theme/app_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_game_repository.dart';
import '../../support/pump_app.dart';

/// Starts the real app (language handling included) with [stored] as the saved language
/// and [device] as the phone's language, then opens Réglages.
Future<void> _openSettingsInApp(
  WidgetTester tester, {
  String? stored,
  Locale device = const Locale('fr', 'FR'),
}) async {
  SharedPreferences.setMockInitialValues({'language': ?stored});
  tester.platformDispatcher.localesTestValue = [device];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [gameRepositoryProvider.overrideWithValue(FakeGameRepository())],
      child: const MainApp(),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byIcon(AppIcons.settings));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the Accueil gear opens Réglages; back returns to Accueil', (tester) async {
    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(FakeGameRepository())],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(AppIcons.settings));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Réglages'), findsOneWidget);

    await tester.tap(find.byIcon(AppIcons.back));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('Réglages says the games stay on the device', (tester) async {
    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(FakeGameRepository())],
      initialLocation: '/settings',
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Vos parties restent sur cet appareil'), findsOneWidget);
  });

  testWidgets('switching the theme segment persists the choice', (tester) async {
    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(FakeGameRepository())],
      initialLocation: '/settings',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sombre'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'dark');
  });

  group('the language', () {
    testWidgets('can be forced from Réglages and is remembered', (tester) async {
      await pumpAppRouter(
        tester,
        overrides: [gameRepositoryProvider.overrideWithValue(FakeGameRepository())],
        initialLocation: '/settings',
      );
      await tester.pumpAndSettle();
      expect(find.text('LANGUE'), findsOneWidget);

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('language'), 'en');
    });

    testWidgets('a stored English choice shows the whole app in English', (tester) async {
      await _openSettingsInApp(tester, stored: 'en');

      expect(find.text('LANGUAGE'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      // The language control and the theme control both have a "System" option.
      expect(find.text('System'), findsNWidgets(2));
      expect(find.text('LANGUE'), findsNothing);
    });

    testWidgets('a stored French choice shows French even on an English device', (tester) async {
      await _openSettingsInApp(tester, stored: 'fr', device: const Locale('en', 'US'));

      expect(find.text('LANGUE'), findsOneWidget);
    });

    testWidgets('following the device gives English on a non-French phone', (tester) async {
      await _openSettingsInApp(tester, device: const Locale('de', 'DE'));

      expect(find.text('LANGUAGE'), findsOneWidget);
    });
  });

  testWidgets('the aide-mémoire toggle flips and persists', (tester) async {
    // Réglages is longer than the default test screen since the language section was added.
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(FakeGameRepository())],
      initialLocation: '/settings',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aide-mémoire dans le script'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('aide_memoire'), isFalse);
  });

  group('deleting every game', () {
    FakeGameRepository repositoryWithGames() {
      final now = DateTime.now();
      return FakeGameRepository(
        initialGames: [
          for (final (i, status) in [
            GameStatus.setup,
            GameStatus.inProgress,
            GameStatus.completed,
          ].indexed)
            Game(
              id: i + 1,
              createdAt: now,
              updatedAt: now,
              playerCount: 8,
              status: status,
            ),
        ],
      );
    }

    Future<void> openSettings(WidgetTester tester, FakeGameRepository repository) async {
      await tester.binding.setSurfaceSize(const Size(400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpAppRouter(
        tester,
        overrides: [gameRepositoryProvider.overrideWithValue(repository)],
        initialLocation: '/settings',
      );
      await tester.pumpAndSettle();
    }

    testWidgets('asks first, then clears drafts, running games and history', (tester) async {
      final repository = repositoryWithGames();
      await openSettings(tester, repository);

      await tester.tap(find.text('Supprimer toutes les parties'));
      await tester.pumpAndSettle();
      expect(find.text('Supprimer toutes les parties ?'), findsOneWidget);
      expect(repository.allGames, hasLength(3));

      await tester.tap(find.text('Tout supprimer'));
      await tester.pumpAndSettle();

      expect(repository.allGames, isEmpty);
      expect(find.text('Toutes les parties sont supprimées.'), findsOneWidget);
    });

    testWidgets('cancelling keeps every game', (tester) async {
      final repository = repositoryWithGames();
      await openSettings(tester, repository);

      await tester.tap(find.text('Supprimer toutes les parties'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(repository.allGames, hasLength(3));
      expect(find.text('Toutes les parties sont supprimées.'), findsNothing);
    });
  });

  testWidgets('Mes boîtes opens from Réglages and is informational', (tester) async {
    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(FakeGameRepository())],
      initialLocation: '/settings',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mes boîtes'));
    await tester.pumpAndSettle();
    expect(find.byType(BoxesScreen), findsOneWidget);
    expect(find.text('Nouvelle Lune'), findsOneWidget);
    expect(find.text('bientôt'), findsWidgets);
  });
}
