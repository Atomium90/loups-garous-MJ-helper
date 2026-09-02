import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/data/database/app_database.dart';
import 'package:loup_garou_mj/data/repositories/drift_game_repository.dart';
import 'package:loup_garou_mj/state/providers/game_repository_provider.dart';

import '../../support/pump_app.dart';

Future<int> _startedGame(DriftGameRepository repo, Map<String, int> composition) async {
  final id = await repo.createGame(initialPlayerCount: 6);
  await repo.saveComposition(gameId: id, playerCount: 6, roleCounts: composition);
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
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(repo)],
      initialLocation: '/games/$id/game',
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  Future<void> identify(WidgetTester tester, List<String> names) async {
    for (final name in names) {
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
    }
    await tap(tester, 'Enregistrer');
  }

  /// Night 1: Voyante = Ana, Loups = Bo+Cy, Sorcière = Di, wolves eat [victim],
  /// Sorcière does nothing, then resolve.
  Future<void> playNight1(WidgetTester tester, {required String victim}) async {
    await identify(tester, ['Ana']);
    await tap(tester, 'Continuer');
    await identify(tester, ['Bo', 'Cy']);
    await tester.tap(find.text(victim));
    await tester.pumpAndSettle();
    await tap(tester, 'Les Loups désignent $victim');
    await identify(tester, ['Di']);
    await tap(tester, 'Terminer le tour de la Sorcière');
    await tap(tester, 'Résoudre la nuit');
  }

  testWidgets('recap CTA -> captain election -> vote -> next night', (tester) async {
    final id = await _startedGame(repo, const {
      'loup_garou': 2,
      'voyante': 1,
      'sorciere': 1,
      'villageois': 2,
    });
    await pump(tester, id);
    await playNight1(tester, victim: 'Ana'); // Ana is the identified Voyante -> no reveal

    // the day recap
    expect(find.text('Jour 1 se lève'), findsOneWidget);
    expect(find.text('Victime des Loups'), findsOneWidget);
    await tap(tester, 'Élire le Capitaine');

    // the captain election
    expect(find.text('Qui est élu ?'), findsOneWidget);
    await tester.tap(find.text('Bo'));
    await tester.pumpAndSettle();
    await tap(tester, 'Bo est Capitaine');

    // the vote - the captain's double vote is named
    expect(find.text('Qui est éliminé ?'), findsOneWidget);
    expect(find.textContaining('voix de Bo compte double'), findsOneWidget);
    await tester.tap(find.text('Cy'));
    await tester.pumpAndSettle();
    await tap(tester, 'Le village élimine Cy');

    // -> next night
    expect(find.text('Commencer la nuit 2'), findsOneWidget);
    await tap(tester, 'Commencer la nuit 2');
    expect(find.text('Nuit 2'), findsOneWidget);
    // the Loups are already known - straight to the action, no re-identification
    expect(find.text('Qui les Loups dévorent-ils ?'), findsOneWidget);
    expect(find.text('Enregistrer'), findsNothing);

    await tap(tester, 'Journal');
    expect(find.text('Bo est Capitaine'), findsOneWidget);
    expect(find.text('Le village élimine Cy'), findsOneWidget);
  });

  testWidgets('an un-identified victim -> reveal panel -> Chasseur chain', (tester) async {
    final id = await _startedGame(repo, const {
      'loup_garou': 2,
      'voyante': 1,
      'sorciere': 1,
      'villageois': 1,
      'chasseur': 1,
    });
    await pump(tester, id);
    await playNight1(tester, victim: 'Fi'); // Fi was never identified

    // reveal panel
    expect(find.text('Quelle était sa carte ?'), findsOneWidget);
    await tester.tap(find.text('Chasseur'));
    await tester.pumpAndSettle();
    await tap(tester, 'Fi était le Chasseur');

    // chain panel: the Hunter's shot
    expect(find.textContaining('Le Chasseur tire', findRichText: true), findsOneWidget);
    expect(find.text('Sa cible'), findsOneWidget);
    await tester.tap(find.text('Ed'));
    await tester.pumpAndSettle();
    await tap(tester, 'Ed est éliminé');

    // chain resolved
    expect(find.text('Sa cible'), findsNothing);

    await tap(tester, 'Journal');
    expect(find.text('Le Chasseur emporte Ed'), findsOneWidget);
  });
}
