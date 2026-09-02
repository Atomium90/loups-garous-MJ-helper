import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/data/database/app_database.dart';
import 'package:loup_garou_mj/data/repositories/drift_game_repository.dart';
import 'package:loup_garou_mj/state/providers/game_repository_provider.dart';
import 'package:loup_garou_mj/ui/widgets/app_button.dart';
import 'package:loup_garou_mj/ui/widgets/player_avatar.dart';

import '../../support/pump_app.dart';

/// A started game with a real Drift repo (GameSession needs the roster round-trip).
Future<int> _startedGame(DriftGameRepository repo, Map<String, int> composition) async {
  final id = await repo.createGame(initialPlayerCount: 4);
  await repo.saveComposition(gameId: id, playerCount: 4, roleCounts: composition);
  await repo.savePlayerNames(gameId: id, names: const ['Ana', 'Bo', 'Cy', 'Di']);
  await repo.startGame(id);
  return id;
}

AppButton _button(WidgetTester tester, String label) =>
    tester.widget<AppButton>(find.widgetWithText(AppButton, label));

void main() {
  late AppDatabase db;
  late DriftGameRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftGameRepository(db);
    addTearDown(db.close);
  });

  testWidgets('the first identify step renders, gates Enregistrer, then advances', (
    tester,
  ) async {
    final id = await _startedGame(repo, const {'loup_garou': 2, 'voyante': 1, 'villageois': 1});

    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(repo)],
      initialLocation: '/games/$id/game',
    );
    await tester.pumpAndSettle();

    // wake order: Voyante (count 1) first
    expect(find.text('Qui est Voyante ?'), findsOneWidget);
    expect(find.text('0 sur 1'), findsOneWidget);
    expect(find.byType(PlayerAvatar), findsNWidgets(4));
    expect(_button(tester, 'Choisissez 1 joueur').onPressed, isNull);

    await tester.tap(find.text('Bo'));
    await tester.pumpAndSettle();
    expect(find.text('1 sur 1'), findsOneWidget);
    expect(_button(tester, 'Enregistrer').onPressed, isNotNull);

    // a single-select step switches on tapping someone else (fix a misclick)
    await tester.tap(find.text('Cy'));
    await tester.pumpAndSettle();
    expect(find.text('1 sur 1'), findsOneWidget);

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    // advanced to the Voyante's act sub-step (its minimal "Continuer")
    expect(find.text('Continuer'), findsOneWidget);
    expect(find.text('Qui est Voyante ?'), findsNothing);
    final roster = await repo.getRoster(id);
    expect(roster.firstWhere((r) => r.name == 'Cy').roleId, 'voyante');
    expect(roster.firstWhere((r) => r.name == 'Bo').roleId, isNull);
  });

  testWidgets('an identified player is no longer offered on the next role\'s grid', (
    tester,
  ) async {
    final id = await _startedGame(repo, const {'loup_garou': 2, 'voyante': 1, 'villageois': 1});

    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(repo)],
      initialLocation: '/games/$id/game',
    );
    await tester.pumpAndSettle();

    // identify Bo as the Voyante, then continue to the Loups' identify step
    await tester.tap(find.text('Bo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    expect(find.text('Qui sont les Loups-Garous ?'), findsOneWidget);
    // Bo is taken - only the 3 remaining players are offered
    expect(find.byType(PlayerAvatar), findsNWidgets(3));
    expect(find.text('Bo'), findsNothing);
  });

  testWidgets('"Je noterai plus tard" skips the step without recording a role', (tester) async {
    final id = await _startedGame(repo, const {'loup_garou': 2, 'voyante': 1, 'villageois': 1});

    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(repo)],
      initialLocation: '/games/$id/game',
    );
    await tester.pumpAndSettle();
    expect(find.text('Qui est Voyante ?'), findsOneWidget);

    await tester.tap(find.text('Je noterai plus tard'));
    await tester.pumpAndSettle();

    // moved on to the Loups' identify step
    expect(find.text('Qui sont les Loups-Garous ?'), findsOneWidget);
    expect(find.text('0 sur 2'), findsOneWidget);
    final roster = await repo.getRoster(id);
    expect(roster.every((r) => r.roleId == null), isTrue);
  });
}
