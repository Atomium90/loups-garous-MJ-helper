import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/data/database/app_database.dart';
import 'package:loup_garou_mj/data/models/game_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loup_garou_mj/main.dart';
import 'package:loup_garou_mj/state/providers/game_repository_provider.dart';
import 'package:loup_garou_mj/state/settings/settings_providers.dart';
import 'package:loup_garou_mj/ui/screens/home/home_screen.dart';
import 'package:loup_garou_mj/ui/screens/settings/boxes_screen.dart';
import 'package:loup_garou_mj/ui/screens/settings/settings_screen.dart';
import 'package:loup_garou_mj/ui/theme/app_icons.dart';
import 'package:loup_garou_mj/ui/widgets/app_toggle.dart';
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
  // Réglages is long: tall enough to see the language section without scrolling.
  await tester.binding.setSurfaceSize(const Size(400, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
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
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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

  testWidgets('the narration level can be changed and is remembered', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(FakeGameRepository())],
      initialLocation: '/settings',
    );
    await tester.pumpAndSettle();
    expect(find.text('PHRASES DU MJ'), findsOneWidget);

    await tester.tap(find.text('Courtes'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('narration_level'), 'short');
  });

  group('the language', () {
    testWidgets('can be forced from Réglages and is remembered', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
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
    await tester.binding.setSurfaceSize(const Size(400, 2400));
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

  testWidgets('the Thief reserve toggle is off by default and persists once flipped', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(FakeGameRepository())],
      initialLocation: '/settings',
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Désactivé : la réserve est tirée au hasard'), findsOneWidget);
    await tester.tap(find.text('Réserve du Voleur choisie par le MJ'));
    await tester.pumpAndSettle();

    expect((await SharedPreferences.getInstance()).getBool('thief_reserve_chosen'), isTrue);
  });

  testWidgets('the tie rule can be chosen and is remembered', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(FakeGameRepository())],
      initialLocation: '/settings',
    );
    await tester.pumpAndSettle();

    expect(find.text('ÉGALITÉ AU VOTE'), findsOneWidget);
    await tester.tap(find.text('2e vote'));
    await tester.pumpAndSettle();

    expect((await SharedPreferences.getInstance()).getString('vote_tie_rule'), 'revote');
  });

  testWidgets('the crash reports are not offered by a build with nowhere to send them', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(FakeGameRepository())],
      initialLocation: '/settings',
    );
    await tester.pumpAndSettle();

    expect(find.text('Envoyer les rapports de plantage'), findsNothing);
  });

  testWidgets('the crash reports are off until flipped, and the choice persists', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAppRouter(
      tester,
      overrides: [
        gameRepositoryProvider.overrideWithValue(FakeGameRepository()),
        crashReportingAvailableProvider.overrideWithValue(true),
      ],
      initialLocation: '/settings',
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Jamais de noms de joueurs'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getBool('crash_reports'), isNull);
    await tester.tap(find.text('Envoyer les rapports de plantage'));
    await tester.pumpAndSettle();

    expect((await SharedPreferences.getInstance()).getBool('crash_reports'), isTrue);
  });

  testWidgets('the dead cards toggle persists once flipped', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(FakeGameRepository())],
      initialLocation: '/settings',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Retourner la carte des morts'));
    await tester.pumpAndSettle();

    expect((await SharedPreferences.getInstance()).getBool('reveal_dead_cards'), isFalse);
  });

  testWidgets('the deal notes toggle is off by default and persists once flipped', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(FakeGameRepository())],
      initialLocation: '/settings',
    );
    await tester.pumpAndSettle();

    expect((await SharedPreferences.getInstance()).getBool('deal_notes_only_if_needed'), isNull);

    await tester.tap(find.text("Ne noter les rôles qu'au besoin"));
    await tester.pumpAndSettle();

    expect((await SharedPreferences.getInstance()).getBool('deal_notes_only_if_needed'), isTrue);
  });

  testWidgets('the Knight disease toggle persists once flipped', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(FakeGameRepository())],
      initialLocation: '/settings',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Maladie du Chevalier en fin de nuit'));
    await tester.pumpAndSettle();

    expect((await SharedPreferences.getInstance()).getBool('knight_disease_night_end'), isTrue);
  });

  testWidgets('the White Werewolf parity toggle persists once flipped', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(FakeGameRepository())],
      initialLocation: '/settings',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Loup-Garou Blanc seul les nuits impaires'));
    await tester.pumpAndSettle();

    expect((await SharedPreferences.getInstance()).getBool('white_wolf_odd_nights'), isTrue);
  });

  testWidgets('the Fox position toggle persists once flipped', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(FakeGameRepository())],
      initialLocation: '/settings',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Renard appelé après la Sorcière'));
    await tester.pumpAndSettle();

    expect((await SharedPreferences.getInstance()).getBool('fox_after_witch'), isTrue);
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
      await tester.binding.setSurfaceSize(const Size(400, 2400));
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

  group('Mes boîtes', () {
    Future<void> openBoxes(WidgetTester tester) async {
      // Tall enough for the six boxes to be on screen at once.
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpAppRouter(
        tester,
        overrides: [gameRepositoryProvider.overrideWithValue(FakeGameRepository())],
        initialLocation: '/settings',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mes boîtes'));
      await tester.pumpAndSettle();
    }

    testWidgets('opens from Réglages and lists the six boxes', (tester) async {
      await openBoxes(tester);

      expect(find.byType(BoxesScreen), findsOneWidget);
      for (final name in [
        'Loups-Garous de Thiercelieux',
        'Nouvelle Lune',
        'Le Village',
        'Personnages',
        'Le Pacte',
        'Best Of',
      ]) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      expect(find.byType(AppToggle), findsNWidgets(6));
    });

    testWidgets('only the base box is owned at first, and it cannot be unticked', (tester) async {
      await openBoxes(tester);

      expect(find.text('8 rôles disponibles pour vos parties'), findsOneWidget);
      final toggles = tester.widgetList<AppToggle>(find.byType(AppToggle)).toList();
      expect(toggles.map((t) => t.value), [true, false, false, false, false, false]);
      expect(toggles.first.onChanged, isNull);
    });

    testWidgets('ticking a box owns it and remembers it', (tester) async {
      await openBoxes(tester);

      await tester.tap(find.byType(AppToggle).at(5)); // Best Of
      await tester.pumpAndSettle();

      final toggles = tester.widgetList<AppToggle>(find.byType(AppToggle)).toList();
      expect(toggles.map((t) => t.value), [true, false, false, false, false, true]);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('owned_boxes'), unorderedEquals(['base', 'best_of']));
    });

    testWidgets('a box ticked earlier is still ticked when the screen opens', (tester) async {
      SharedPreferences.setMockInitialValues({
        'owned_boxes': ['base', 'characters'],
      });
      await openBoxes(tester);

      final toggles = tester.widgetList<AppToggle>(find.byType(AppToggle)).toList();
      expect(toggles.map((t) => t.value), [true, false, false, true, false, false]);
    });

    testWidgets('the Réglages row sums up the owned boxes', (tester) async {
      SharedPreferences.setMockInitialValues({
        'owned_boxes': ['base', 'best_of'],
      });
      await pumpAppRouter(
        tester,
        overrides: [gameRepositoryProvider.overrideWithValue(FakeGameRepository())],
        initialLocation: '/settings',
      );
      await tester.pumpAndSettle();

      expect(find.text('2 boîtes · 20 rôles'), findsOneWidget);
    });
  });
}
