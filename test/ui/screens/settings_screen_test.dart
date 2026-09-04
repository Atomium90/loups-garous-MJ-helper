import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/state/providers/game_repository_provider.dart';
import 'package:loup_garou_mj/ui/screens/home/home_screen.dart';
import 'package:loup_garou_mj/ui/screens/settings/boxes_screen.dart';
import 'package:loup_garou_mj/ui/screens/settings/settings_screen.dart';
import 'package:loup_garou_mj/ui/theme/app_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_game_repository.dart';
import '../../support/pump_app.dart';

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

  testWidgets('the aide-mémoire toggle flips and persists', (tester) async {
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
