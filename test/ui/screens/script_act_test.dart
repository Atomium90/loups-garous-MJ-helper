import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/data/database/app_database.dart';
import 'package:loup_garou_mj/data/repositories/drift_game_repository.dart';
import 'package:loup_garou_mj/state/providers/game_repository_provider.dart';

import '../../support/pump_app.dart';

Future<int> _startedGame(DriftGameRepository repo) async {
  final id = await repo.createGame(initialPlayerCount: 6);
  await repo.saveComposition(
    gameId: id,
    playerCount: 6,
    roleCounts: const {'loup_garou': 2, 'voyante': 1, 'sorciere': 1, 'villageois': 2},
  );
  await repo.savePlayerNames(gameId: id, names: const ['Ana', 'Bo', 'Cy', 'Di', 'Ed', 'Fi']);
  await repo.startGame(id);
  return id;
}

void main() {
  late AppDatabase db;
  late DriftGameRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftGameRepository(db);
    addTearDown(db.close);
  });

  Future<void> pump(WidgetTester tester, int id) async {
    // A tall, phone-wide surface so the selection grid + buttons all fit
    // without scrolling (real phones scroll; the point here is deterministic
    // taps). setSurfaceSize takes logical pixels directly.
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(repo)],
      initialLocation: '/games/$id/game',
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapName(WidgetTester tester, String name) async {
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  Future<void> identify(WidgetTester tester, List<String> names) async {
    for (final name in names) {
      await tapName(tester, name);
    }
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
  }

  testWidgets('play night 1 to the day recap: wolves eat Di, Witch does nothing', (tester) async {
    final id = await _startedGame(repo);
    await pump(tester, id);

    // Voyante
    await identify(tester, ['Ana']);
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    // Loups
    await identify(tester, ['Bo', 'Cy']);
    expect(find.text('Qui les Loups dévorent-ils ?'), findsOneWidget);
    // wolves aren't offered as targets
    expect(find.text('Bo'), findsNothing);
    await tapName(tester, 'Di');
    await tester.tap(find.text('Les Loups désignent Di'));
    await tester.pumpAndSettle();

    // Sorcière
    await identify(tester, ['Ed']);
    expect(find.text('Victime des Loups cette nuit'), findsOneWidget);
    await tester.tap(find.text('Terminer le tour de la Sorcière'));
    await tester.pumpAndSettle();

    // Resolve
    expect(find.text('Résoudre la nuit'), findsOneWidget);
    await tester.tap(find.text('Résoudre la nuit'));
    await tester.pumpAndSettle();

    // Day recap
    expect(find.text('Jour 1 se lève'), findsOneWidget);
    expect(find.text('Cette nuit, le village a perdu'), findsOneWidget);
    expect(find.text('Victime des Loups'), findsOneWidget);
    expect(find.text('Di'), findsWidgets);

    final roster = await repo.getRoster(id);
    expect(roster.firstWhere((r) => r.name == 'Di').roleId, isNull); // never identified

    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();
    expect(find.text('Les Loups désignent Di'), findsOneWidget);
  });

  testWidgets('the Witch can save the wolves\' victim', (tester) async {
    final id = await _startedGame(repo);
    await pump(tester, id);

    await identify(tester, ['Ana']);
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    await identify(tester, ['Bo', 'Cy']);
    await tapName(tester, 'Di');
    await tester.tap(find.text('Les Loups désignent Di'));
    await tester.pumpAndSettle();

    await identify(tester, ['Ed']);
    await tester.tap(find.text('Elle sauve Di'));
    await tester.pumpAndSettle();

    // life potion spent, save button gone
    expect(find.text('Vie utilisée'), findsOneWidget);
    expect(find.text('Elle sauve Di'), findsNothing);

    await tester.tap(find.text('Terminer le tour de la Sorcière'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Résoudre la nuit'));
    await tester.pumpAndSettle();

    expect(find.text("Personne n'est mort cette nuit"), findsOneWidget);

    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();
    expect(find.text('La Sorcière sauve Di'), findsOneWidget);
  });

  testWidgets('the Witch can poison someone (sub-picker returns to the potion view)', (
    tester,
  ) async {
    final id = await _startedGame(repo);
    await pump(tester, id);

    await identify(tester, ['Ana']);
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    await identify(tester, ['Bo', 'Cy']);
    await tapName(tester, 'Di');
    await tester.tap(find.text('Les Loups désignent Di'));
    await tester.pumpAndSettle();
    await identify(tester, ['Ed']);

    await tester.tap(find.text('Elle empoisonne…'));
    await tester.pumpAndSettle();
    await tapName(tester, 'Fi');
    await tester.tap(find.text('Elle empoisonne Fi'));
    await tester.pumpAndSettle();

    // back on the potion view, death potion spent
    expect(find.text('Mort utilisée'), findsOneWidget);
    expect(find.text('Terminer le tour de la Sorcière'), findsOneWidget);

    await tester.tap(find.text('Terminer le tour de la Sorcière'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Résoudre la nuit'));
    await tester.pumpAndSettle();

    // Di (wolves) and Fi (poison) both dead
    expect(find.text('Di'), findsWidgets);
    expect(find.text('Fi'), findsWidgets);
    expect(find.text('Potion de mort de la Sorcière'), findsOneWidget);
  });
}
