import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/data/database/app_database.dart';
import 'package:loup_garou_mj/data/models/game_status.dart';
import 'package:loup_garou_mj/state/providers/game_repository_provider.dart';
import 'package:loup_garou_mj/ui/screens/before_night/before_night_screen.dart';
import 'package:loup_garou_mj/ui/screens/composition/composition_screen.dart';
import 'package:loup_garou_mj/ui/screens/players/players_screen.dart';
import 'package:loup_garou_mj/ui/theme/app_icons.dart';

import '../../support/fake_game_repository.dart';
import '../../support/pump_app.dart';

/// A game that went through setup as far as [named] seats.
Future<int> _draft(
  FakeGameRepository repo, {
  bool composed = false,
  List<String>? names,
}) async {
  final id = await repo.createGame(initialPlayerCount: 4);
  if (composed) {
    await repo.saveComposition(
      gameId: id,
      playerCount: 4,
      roleCounts: const {'loup_garou': 1, 'villageois': 3},
    );
  }
  if (names != null) await repo.savePlayerNames(gameId: id, names: names);
  return id;
}

Future<void> _pumpHome(WidgetTester tester, FakeGameRepository repo) async {
  await tester.binding.setSurfaceSize(const Size(400, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await pumpAppRouter(tester, overrides: [gameRepositoryProvider.overrideWithValue(repo)]);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a home with only drafts lists them instead of showing a blank page', (
    tester,
  ) async {
    final repo = FakeGameRepository();
    await _draft(repo);
    await _pumpHome(tester, repo);

    expect(find.text('BROUILLONS'), findsOneWidget);
    expect(find.text('Composition à faire'), findsOneWidget);
    expect(find.text('Nouvelle partie'), findsOneWidget);
    expect(find.text('Aucune partie'), findsNothing);
  });

  testWidgets('each draft says how far it got', (tester) async {
    final repo = FakeGameRepository();
    await _draft(repo);
    await _draft(repo, composed: true);
    await _draft(repo, composed: true, names: const ['Ana', 'Bo', 'Cy', 'Di']);
    await _pumpHome(tester, repo);

    expect(find.text('Composition à faire'), findsOneWidget);
    expect(find.text('Joueurs à nommer'), findsOneWidget);
    expect(find.text('Prête à démarrer'), findsOneWidget);
  });

  testWidgets('a draft whose composition was only started still resumes on the composition', (
    tester,
  ) async {
    final repo = FakeGameRepository();
    final id = await repo.createGame(initialPlayerCount: 8);
    await repo.saveCompositionDraft(
      gameId: id,
      playerCount: 8,
      roleCounts: const {'voyante': 1},
    );
    await _pumpHome(tester, repo);

    expect(find.text('Composition à faire'), findsOneWidget);
    await tester.tap(find.text('Composition à faire'));
    await tester.pumpAndSettle();

    expect(find.byType(CompositionScreen), findsOneWidget);
    expect(find.text('1 rôles pour 8 joueurs'), findsOneWidget);
  });

  testWidgets('a started game is not listed under Brouillons', (tester) async {
    final now = DateTime.now();
    final repo = FakeGameRepository(
      initialGames: [
        Game(
          id: 1,
          name: 'En route',
          createdAt: now,
          updatedAt: now,
          playerCount: 8,
          status: GameStatus.inProgress,
        ),
      ],
    );
    await _pumpHome(tester, repo);

    expect(find.text('BROUILLONS'), findsNothing);
    expect(find.text('En route'), findsOneWidget);
  });

  group('resuming a draft', () {
    testWidgets('without a composition opens the composition', (tester) async {
      final repo = FakeGameRepository();
      await _draft(repo);
      await _pumpHome(tester, repo);

      await tester.tap(find.text('Composition à faire'));
      await tester.pumpAndSettle();

      expect(find.byType(CompositionScreen), findsOneWidget);
    });

    testWidgets('with unnamed players opens the players screen', (tester) async {
      final repo = FakeGameRepository();
      await _draft(repo, composed: true);
      await _pumpHome(tester, repo);

      await tester.tap(find.text('Joueurs à nommer'));
      await tester.pumpAndSettle();

      expect(find.byType(PlayersScreen), findsOneWidget);
    });

    testWidgets('with every player named opens the screen before the night', (tester) async {
      final repo = FakeGameRepository();
      await _draft(repo, composed: true, names: const ['Ana', 'Bo', 'Cy', 'Di']);
      await _pumpHome(tester, repo);

      await tester.tap(find.text('Prête à démarrer'));
      await tester.pumpAndSettle();

      expect(find.byType(BeforeNightScreen), findsOneWidget);
    });
  });

  group('deleting a draft', () {
    testWidgets('removes it after confirmation and leaves the others', (tester) async {
      final repo = FakeGameRepository();
      final removed = await _draft(repo);
      final kept = await _draft(repo, composed: true);
      await _pumpHome(tester, repo);

      // the delete button of the draft that has no composition yet
      final row = find.ancestor(
        of: find.text('Composition à faire'),
        matching: find.byType(InkWell),
      );
      await tester.tap(find.descendant(of: row.first, matching: find.byIcon(AppIcons.delete)));
      await tester.pumpAndSettle();
      expect(find.text('Supprimer ce brouillon ?'), findsOneWidget);

      await tester.tap(find.text('Supprimer ce brouillon'));
      await tester.pumpAndSettle();

      expect(await repo.getGame(removed), isNull);
      expect(await repo.getGame(kept), isNotNull);
      expect(find.text('Composition à faire'), findsNothing);
      expect(find.text('Joueurs à nommer'), findsOneWidget);
    });

    testWidgets('cancelling keeps the draft', (tester) async {
      final repo = FakeGameRepository();
      final id = await _draft(repo);
      await _pumpHome(tester, repo);

      await tester.tap(find.byIcon(AppIcons.delete));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(await repo.getGame(id), isNotNull);
      expect(find.text('Composition à faire'), findsOneWidget);
    });

    testWidgets('deleting the last draft brings back the empty state', (tester) async {
      final repo = FakeGameRepository();
      await _draft(repo);
      await _pumpHome(tester, repo);

      await tester.tap(find.byIcon(AppIcons.delete));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer ce brouillon'));
      await tester.pumpAndSettle();

      expect(find.text('Aucune partie'), findsOneWidget);
    });
  });
}
