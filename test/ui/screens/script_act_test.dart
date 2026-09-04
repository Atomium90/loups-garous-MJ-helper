import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/data/database/app_database.dart';
import 'package:loup_garou_mj/data/repositories/drift_game_repository.dart';
import 'package:loup_garou_mj/state/providers/game_repository_provider.dart';
import 'package:loup_garou_mj/ui/widgets/player_avatar.dart';

import '../../support/pump_app.dart';

Future<int> _startedGame(
  DriftGameRepository repo, {
  Map<String, int> composition = const {
    'loup_garou': 2,
    'voyante': 1,
    'sorciere': 1,
    'villageois': 2,
  },
  List<String> reserveRoleIds = const [],
}) async {
  final id = await repo.createGame(initialPlayerCount: 6);
  await repo.saveComposition(
    gameId: id,
    playerCount: 6,
    roleCounts: composition,
    reserveRoleIds: reserveRoleIds,
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

  /// After resolving the night, an un-identified victim raises the reveal panel.
  /// These night-focused tests don't care about the card, so just dismiss each.
  Future<void> clearReveals(WidgetTester tester) async {
    while (find.text('Je ne note pas').evaluate().isNotEmpty) {
      await tester.tap(find.text('Je ne note pas'));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('play night 1 to the day recap: wolves eat Di, Witch does nothing', (tester) async {
    final id = await _startedGame(repo);
    await pump(tester, id);

    // Voyante
    await identify(tester, ['Ana']);
    await tester.tap(find.text('Passer ce rôle')); // skip the Voyante's look
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
    await clearReveals(tester);

    // Day recap
    expect(find.text('JOUR 1 SE LÈVE'), findsOneWidget);
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
    await tester.tap(find.text('Passer ce rôle')); // skip the Voyante's look
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

  testWidgets('the Voyante looks at an unknown player and the MJ notes the card', (
    tester,
  ) async {
    final id = await _startedGame(repo);
    await pump(tester, id);

    await identify(tester, ['Ana']); // Voyante = Ana

    expect(find.text('Qui la Voyante observe-t-elle ?'), findsOneWidget);
    await tapName(tester, 'Bo');
    await tester.tap(find.text('La Voyante observe Bo'));
    await tester.pumpAndSettle();

    // Bo's card isn't on record -> the MJ notes it
    expect(find.text('La carte de Bo'), findsOneWidget);
    await tester.tap(find.text('Loup-Garou'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bo est le Loup-Garou'));
    await tester.pumpAndSettle();

    // inline reveal
    expect(find.text('La Voyante voit'), findsOneWidget);
    expect(find.text('Bo est le Loup-Garou'), findsOneWidget);
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    // advanced to the Loups' step - Bo is a known wolf now, so it shows him
    // locked and only asks for the one remaining dealt wolf
    expect(find.text('Déjà connu grâce à la Voyante.'), findsOneWidget);
    expect(find.text('0 sur 1'), findsOneWidget);
    expect((await repo.getRoster(id)).firstWhere((r) => r.name == 'Bo').roleId, 'loup_garou');
    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();
    expect(find.text('La Voyante observe Bo'), findsOneWidget);
  });

  testWidgets('the Voyante can\'t look at herself, and a known card shows straight away', (
    tester,
  ) async {
    final id = await _startedGame(
      repo,
      composition: const {'voleur': 1, 'voyante': 1, 'loup_garou': 2, 'villageois': 2},
      reserveRoleIds: const ['chasseur', 'sorciere'],
    );
    await pump(tester, id);

    await identify(tester, ['Ana']); // Voleur = Ana
    await tester.tap(find.text('Il garde sa carte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Le Voleur garde sa carte'));
    await tester.pumpAndSettle();

    await identify(tester, ['Bo']); // Voyante = Bo
    expect(find.text('Qui la Voyante observe-t-elle ?'), findsOneWidget);
    // 6 players minus Bo herself = 5 cells on her grid
    expect(find.byType(PlayerAvatar), findsNWidgets(5));

    // Ana's card is on record (she kept the Voleur) -> straight to the reveal
    await tapName(tester, 'Ana');
    await tester.tap(find.text('La Voyante observe Ana'));
    await tester.pumpAndSettle();
    expect(find.text('La carte de Ana'), findsNothing);
    expect(find.text('La Voyante voit'), findsOneWidget);
    expect(find.text('Ana est le Voleur'), findsOneWidget);
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    expect(find.text('Qui sont les Loups-Garous ?'), findsOneWidget);
  });

  testWidgets('the Voleur swaps his card for a reserve card', (tester) async {
    final id = await _startedGame(
      repo,
      composition: const {'voleur': 1, 'loup_garou': 2, 'sorciere': 1, 'villageois': 2},
      reserveRoleIds: const ['voyante', 'chasseur'],
    );
    await pump(tester, id);

    // Voleur = Ana
    await identify(tester, ['Ana']);

    expect(find.text('Les deux cartes de la pioche'), findsOneWidget);
    expect(find.text('Il garde sa carte'), findsOneWidget);

    await tester.tap(find.text('Voyante'));
    await tester.pumpAndSettle();
    // stealing a night role warns the MJ
    expect(find.textContaining('Le Voleur devient la Voyante'), findsOneWidget);

    await tester.tap(find.text('Le Voleur prend la Voyante'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();
    expect(find.text('Le Voleur échange sa carte contre Voyante'), findsOneWidget);
  });

  testWidgets('a Voleur who steals a Loup is a locked extra on the wolves grid', (tester) async {
    final id = await _startedGame(
      repo,
      composition: const {'voleur': 1, 'loup_garou': 2, 'sorciere': 1, 'villageois': 2},
      reserveRoleIds: const ['loup_garou', 'chasseur'],
    );
    await pump(tester, id);

    await identify(tester, ['Ana']); // Voleur = Ana
    await tester.tap(find.text('Loup-Garou'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Le Voleur prend le Loup-Garou'));
    await tester.pumpAndSettle();

    // straight onto the wolves' identify step
    expect(find.text('Qui sont les Loups-Garous ?'), findsOneWidget);
    expect(find.textContaining('Le Voleur a volé une carte de Loup-Garou'), findsOneWidget);
    // still asks for the 2 dealt wolves (Ana is the locked +1)
    expect(find.text('0 sur 2'), findsOneWidget);
    // Ana shows on the grid but tapping her does nothing
    expect(find.text('Ana'), findsOneWidget);
    await tester.tap(find.text('Ana'));
    await tester.pump();
    expect(find.text('0 sur 2'), findsOneWidget);

    await tester.tap(find.text('Bo'));
    await tester.tap(find.text('Cy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    // wolves recorded: Ana (stolen) + Bo + Cy
    final roster = await repo.getRoster(id);
    expect(
      roster.where((r) => r.roleId == 'loup_garou').map((r) => r.name).toSet(),
      {'Ana', 'Bo', 'Cy'},
    );
  });

  testWidgets('the Witch can poison someone (sub-picker returns to the potion view)', (
    tester,
  ) async {
    final id = await _startedGame(repo);
    await pump(tester, id);

    await identify(tester, ['Ana']);
    await tester.tap(find.text('Passer ce rôle')); // skip the Voyante's look
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
    await clearReveals(tester);

    // Di (wolves) and Fi (poison) both dead
    expect(find.text('Di'), findsWidgets);
    expect(find.text('Fi'), findsWidgets);
    expect(find.text('Potion de mort de la Sorcière'), findsOneWidget);
  });
}
