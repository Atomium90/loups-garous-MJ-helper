import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loup_garou_mj/data/models/game_status.dart';
import 'package:loup_garou_mj/state/providers/game_repository_provider.dart';
import 'package:loup_garou_mj/ui/screens/before_night/before_night_screen.dart';
import 'package:loup_garou_mj/ui/screens/before_night/deal_role_sheet.dart';
import 'package:loup_garou_mj/ui/screens/in_game/script_tab.dart';

import '../../support/fake_game_repository.dart';
import '../../support/pump_app.dart';

/// A setup game with the given composition and a fully-named roster.
Future<int> _readyToDeal(
  FakeGameRepository repo, {
  required Map<String, int> composition,
  required List<String> names,
  List<String> reserveRoleIds = const [],
}) async {
  final id = await repo.createGame(initialPlayerCount: names.length);
  await repo.saveComposition(
    gameId: id,
    playerCount: names.length,
    roleCounts: composition,
    reserveRoleIds: reserveRoleIds,
  );
  await repo.savePlayerNames(gameId: id, names: names);
  return id;
}

void main() {
  // The settings live in SharedPreferences, which outlives a test: start each one on the defaults.
  setUp(() => SharedPreferences.setMockInitialValues({}));

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
    expect(find.text('2 Loups-Garous · Voyante · 3 Simples Villageois'), findsOneWidget);
    expect(find.text('Réserve du Voleur'), findsNothing);
  });

  testWidgets('spells out the Voleur reserve cards when the composition has one', (
    tester,
  ) async {
    final repository = FakeGameRepository();
    final id = await _readyToDeal(
      repository,
      composition: const {'voleur': 1, 'loup_garou': 2, 'villageois': 3},
      names: const ['Camille', 'Julien', 'Noa', 'Lina', 'Théo', 'Awa'],
      reserveRoleIds: const ['chasseur', 'cupidon'],
    );

    await pumpScreen(
      tester,
      BeforeNightScreen(gameId: id),
      overrides: [gameRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    expect(find.text('Réserve du Voleur'), findsOneWidget);
    expect(
      find.textContaining('le Chasseur · le Cupidon'),
      findsOneWidget,
    );
  });

  testWidgets('a Voleur with a drawn reserve adds two Simples Villageois to the pack', (
    tester,
  ) async {
    final repository = FakeGameRepository();
    final id = await _readyToDeal(
      repository,
      composition: const {'voleur': 1, 'loup_garou': 2, 'villageois': 3},
      names: const ['Camille', 'Julien', 'Noa', 'Lina', 'Théo', 'Awa'],
    );

    await pumpScreen(
      tester,
      BeforeNightScreen(gameId: id),
      overrides: [gameRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    expect(find.text('Réserve du Voleur'), findsOneWidget);
    expect(find.textContaining('Ajoutez 2 Simples Villageois au paquet (8 cartes)'), findsOneWidget);
    // The deck line counts them: 3 + 2 villagers in the pack.
    expect(find.text('2 Loups-Garous · Voleur · 5 Simples Villageois'), findsOneWidget);
  });

  testWidgets('with the Angel the game starts with a debate, and says so', (tester) async {
    final repository = FakeGameRepository();
    final id = await _readyToDeal(
      repository,
      composition: const {'ange': 1, 'loup_garou': 2, 'villageois': 3},
      names: const ['Camille', 'Julien', 'Noa', 'Lina', 'Théo', 'Awa'],
    );

    await pumpScreen(
      tester,
      BeforeNightScreen(gameId: id),
      overrides: [gameRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    expect(find.textContaining("L'Ange est en jeu : la partie commence par un débat"), findsOneWidget);
    expect(find.text('Commencer par le débat'), findsOneWidget);
    expect(find.text('Commencer la nuit 1'), findsNothing);
  });

  group('noting the cards at the deal', () {
    const names = ['Camille', 'Julien', 'Noa', 'Lina', 'Théo', 'Awa'];
    const plain = {'loup_garou': 2, 'voyante': 1, 'villageois': 3};

    Future<void> open(WidgetTester tester, FakeGameRepository repository, int id) async {
      await pumpScreen(
        tester,
        BeforeNightScreen(gameId: id),
        overrides: [gameRepositoryProvider.overrideWithValue(repository)],
      );
      await tester.pumpAndSettle();
    }

    Finder inSheet(String text) =>
        find.descendant(of: find.byType(DealRoleSheet), matching: find.text(text));

    testWidgets('tapping a player offers the cards of the deal and notes the one chosen', (
      tester,
    ) async {
      final repository = FakeGameRepository();
      final id = await _readyToDeal(repository, composition: plain, names: names);
      await open(tester, repository, id);

      expect(find.text('0/6 notés'), findsOneWidget);
      expect(find.textContaining('notez la carte de chaque joueur'), findsOneWidget);

      await tester.tap(find.text('Camille'));
      await tester.pumpAndSettle();

      expect(find.text('Carte de Camille'), findsOneWidget);
      expect(inSheet('Loup-Garou'), findsOneWidget);
      expect(inSheet('×2'), findsOneWidget);
      expect(inSheet('Simple Villageois'), findsOneWidget);
      expect(inSheet('×3'), findsOneWidget);

      await tester.tap(inSheet('Voyante'));
      await tester.pumpAndSettle();

      expect(find.byType(DealRoleSheet), findsNothing);
      expect(find.text('Voyante'), findsOneWidget);
      expect(find.text('1/6 notés'), findsOneWidget);
      expect((await repository.getRoster(id))[0].roleId, 'voyante');
    });

    testWidgets('a card already given is no longer offered, but its holder can change or clear it', (
      tester,
    ) async {
      final repository = FakeGameRepository();
      final id = await _readyToDeal(repository, composition: plain, names: names);
      await open(tester, repository, id);

      await tester.tap(find.text('Camille'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet('Voyante'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Julien'));
      await tester.pumpAndSettle();
      expect(inSheet('Voyante'), findsNothing);
      expect(inSheet('Retirer la carte notée'), findsNothing);
      await tester.tap(inSheet('Loup-Garou'));
      await tester.pumpAndSettle();
      expect(find.text('2/6 notés'), findsOneWidget);

      // Camille's own sheet still offers her card, and lets her forget it.
      await tester.tap(find.text('Camille'));
      await tester.pumpAndSettle();
      expect(inSheet('Voyante'), findsOneWidget);
      await tester.tap(inSheet('Retirer la carte notée'));
      await tester.pumpAndSettle();

      expect((await repository.getRoster(id))[0].roleId, isNull);
      expect(find.text('1/6 notés'), findsOneWidget);
    });

    testWidgets('a drawn Voleur reserve puts two more Simples Villageois in the pack', (
      tester,
    ) async {
      final repository = FakeGameRepository();
      final id = await _readyToDeal(
        repository,
        composition: const {'voleur': 1, 'loup_garou': 2, 'villageois': 3},
        names: names,
      );
      await open(tester, repository, id);

      await tester.tap(find.text('Camille'));
      await tester.pumpAndSettle();

      expect(inSheet('×5'), findsOneWidget);
    });

    testWidgets('asked to note only when needed, a plain composition is dealt blind', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'deal_notes_only_if_needed': true});
      final repository = FakeGameRepository();
      final id = await _readyToDeal(repository, composition: plain, names: names);
      await open(tester, repository, id);

      expect(find.textContaining('notés'), findsNothing);
      expect(find.textContaining("distribuez à l'aveugle"), findsOneWidget);

      await tester.tap(find.text('Camille'));
      await tester.pumpAndSettle();

      expect(find.byType(DealRoleSheet), findsNothing);
    });

    testWidgets('asked to note only when needed, a role that needs it brings the notes back', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'deal_notes_only_if_needed': true});
      final repository = FakeGameRepository();
      final id = await _readyToDeal(
        repository,
        composition: const {'renard': 1, 'loup_garou': 2, 'villageois': 3},
        names: names,
      );
      await open(tester, repository, id);

      expect(find.text('0/6 notés'), findsOneWidget);
    });

    testWidgets('the cards noted are still there when the game starts', (tester) async {
      final repository = FakeGameRepository();
      final id = await _readyToDeal(repository, composition: plain, names: names);
      await pumpAppRouter(
        tester,
        overrides: [gameRepositoryProvider.overrideWithValue(repository)],
        initialLocation: '/games/$id/before-night',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Camille'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet('Voyante'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Commencer la nuit 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Commencer quand même'));
      await tester.pumpAndSettle();

      expect((await repository.getGame(id))!.status, GameStatus.inProgress);
      expect((await repository.getRoster(id))[0].roleId, 'voyante');
    });

    testWidgets('starting with cards not noted asks first, and cancelling keeps the deal open', (
      tester,
    ) async {
      final repository = FakeGameRepository();
      final id = await _readyToDeal(repository, composition: plain, names: names);
      await pumpAppRouter(
        tester,
        overrides: [gameRepositoryProvider.overrideWithValue(repository)],
        initialLocation: '/games/$id/before-night',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Camille'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet('Voyante'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Commencer la nuit 1'));
      await tester.pumpAndSettle();

      expect(find.text('Des cartes ne sont pas notées'), findsOneWidget);
      expect(find.textContaining('5 joueurs n'), findsOneWidget);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect((await repository.getGame(id))!.status, GameStatus.setup);
      expect(find.byType(BeforeNightScreen), findsOneWidget);
    });

    testWidgets('with every card noted the game starts without asking', (tester) async {
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
      for (final (name, card) in [
        ('Lina', 'Loup-Garou'),
        ('Théo', 'Voyante'),
        ('Awa', 'Simple Villageois'),
      ]) {
        await tester.tap(find.text(name));
        await tester.pumpAndSettle();
        await tester.tap(inSheet(card));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Commencer la nuit 1'));
      await tester.pumpAndSettle();

      expect(find.text('Des cartes ne sont pas notées'), findsNothing);
      expect((await repository.getGame(id))!.status, GameStatus.inProgress);
    });

    testWidgets('a deal that is not noted at all starts without asking', (tester) async {
      SharedPreferences.setMockInitialValues({'deal_notes_only_if_needed': true});
      final repository = FakeGameRepository();
      final id = await _readyToDeal(repository, composition: plain, names: names);
      await pumpAppRouter(
        tester,
        overrides: [gameRepositoryProvider.overrideWithValue(repository)],
        initialLocation: '/games/$id/before-night',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Commencer la nuit 1'));
      await tester.pumpAndSettle();

      expect(find.text('Des cartes ne sont pas notées'), findsNothing);
      expect((await repository.getGame(id))!.status, GameStatus.inProgress);
    });
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
    // Nothing is noted at the deal: the MJ is asked whether to go on blind.
    await tester.tap(find.text('Commencer quand même'));
    await tester.pumpAndSettle();

    expect((await repository.getGame(id))!.status, GameStatus.inProgress);
    expect(find.byType(ScriptTab), findsOneWidget);
    expect(find.text('NUIT 1'), findsOneWidget);
  });
}
