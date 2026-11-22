import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart' show ListTile;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/data/database/app_database.dart';
import 'package:loup_garou_mj/data/repositories/drift_game_repository.dart';
import 'package:loup_garou_mj/state/providers/game_repository_provider.dart';
import 'package:loup_garou_mj/ui/widgets/app_button.dart';
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
    // Di's card was never noted -> the recap says so rather than staying silent.
    expect(find.text('Rôle non révélé'), findsOneWidget);

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

  group('the Defender', () {
    const comp = {'salvateur': 1, 'loup_garou': 2, 'villageois': 3};

    testWidgets('protects someone, and the Witch no longer sees them as the victim', (tester) async {
      final id = await _startedGame(
        repo,
        composition: const {'salvateur': 1, 'loup_garou': 2, 'sorciere': 1, 'villageois': 2},
      );
      await pump(tester, id);

      await identify(tester, ['Ana']); // the Defender
      expect(find.text('Qui le Salvateur protège-t-il ?'), findsOneWidget);
      await tapName(tester, 'Di');
      await tester.tap(find.text('Le Salvateur protège Di'));
      await tester.pumpAndSettle();

      await identify(tester, ['Bo', 'Cy']); // the wolves
      await tapName(tester, 'Di');
      await tester.tap(find.text('Les Loups désignent Di'));
      await tester.pumpAndSettle();
      await identify(tester, ['Ed']); // the Witch

      expect(find.text('Victime des Loups cette nuit'), findsNothing);
    });

    testWidgets('the call can be passed', (tester) async {
      final id = await _startedGame(repo, composition: comp);
      await pump(tester, id);

      await identify(tester, ['Ana']);
      await tester.tap(find.text('Passer ce rôle'));
      await tester.pumpAndSettle();

      expect(find.text('Qui sont les Loups-Garous ?'), findsOneWidget);
    });
  });

  group('the Piper', () {
    const comp = {'joueur_de_flute': 1, 'loup_garou': 2, 'villageois': 3};

    Future<void> toPiper(WidgetTester tester) async {
      await identify(tester, ['Bo', 'Cy']); // the wolves
      await tapName(tester, 'Fi');
      await tester.tap(find.text('Les Loups désignent Fi'));
      await tester.pumpAndSettle();
      await identify(tester, ['Ana']); // the Piper
    }

    testWidgets('charms two players, then the charmed meet', (tester) async {
      final id = await _startedGame(repo, composition: comp);
      await pump(tester, id);
      await toPiper(tester);

      expect(find.text('Qui le Joueur de Flûte charme-t-il ?'), findsOneWidget);
      await tapName(tester, 'Di');
      await tapName(tester, 'Ed');
      await tester.tap(find.text('Le Joueur de Flûte charme Di et Ed'));
      await tester.pumpAndSettle();

      // the charmed wake: the card names them
      expect(find.text('Ils se sont reconnus'), findsOneWidget);
      await tester.tap(find.text('Ils se sont reconnus'));
      await tester.pumpAndSettle();
      expect(find.text('Résoudre la nuit'), findsOneWidget);

      await tester.tap(find.text('Journal'));
      await tester.pumpAndSettle();
      expect(find.text('Le Joueur de Flûte charme Di et Ed'), findsOneWidget);
    });

    testWidgets('does not offer himself', (tester) async {
      final id = await _startedGame(repo, composition: comp);
      await pump(tester, id);
      await toPiper(tester);

      // Ana is the Piper: she is not among the players to charm (4 are: Bo, Cy, Di, Ed)
      expect(find.text('0 / 2'), findsNothing);
      await tapName(tester, 'Bo');
      await tapName(tester, 'Cy');
      expect(find.text('Le Joueur de Flûte charme Bo et Cy'), findsOneWidget);
    });

    testWidgets('the call can be passed', (tester) async {
      final id = await _startedGame(repo, composition: comp);
      await pump(tester, id);
      await toPiper(tester);

      await tester.tap(find.text('Passer ce rôle'));
      await tester.pumpAndSettle();

      expect(find.text('Résoudre la nuit'), findsOneWidget);
    });
  });

  group('the Elder', () {
    const comp = {'ancien': 1, 'loup_garou': 2, 'villageois': 3};

    testWidgets('is asked about when the wolves pick someone, and a "yes" spares the first bite', (
      tester,
    ) async {
      final id = await _startedGame(repo, composition: comp);
      await pump(tester, id);

      await identify(tester, ['Bo', 'Cy']);
      await tapName(tester, 'Ana');
      await tester.tap(find.text('Les Loups désignent Ana'));
      await tester.pumpAndSettle();

      expect(find.text("Est-ce l'Ancien ?"), findsOneWidget);
      await tester.tap(find.text("Oui, c'est l'Ancien"));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Résoudre la nuit'));
      await tester.pumpAndSettle();
      expect(find.text("Personne n'est mort cette nuit"), findsOneWidget);
      await tester.tap(find.text('Journal'));
      await tester.pumpAndSettle();
      expect(find.text("Ana, l'Ancien, survit à la morsure"), findsOneWidget);
    });

    testWidgets('a "no" lets the victim die as usual', (tester) async {
      final id = await _startedGame(repo, composition: comp);
      await pump(tester, id);

      await identify(tester, ['Bo', 'Cy']);
      await tapName(tester, 'Ana');
      await tester.tap(find.text('Les Loups désignent Ana'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Non'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Résoudre la nuit'));
      await tester.pumpAndSettle();
      expect(find.text("Personne n'est mort cette nuit"), findsNothing);
    });

    testWidgets('is not asked about when there is no Elder in the game', (tester) async {
      final id = await _startedGame(
        repo,
        composition: const {'loup_garou': 2, 'villageois': 4},
      );
      await pump(tester, id);

      await identify(tester, ['Bo', 'Cy']);
      await tapName(tester, 'Ana');
      await tester.tap(find.text('Les Loups désignent Ana'));
      await tester.pumpAndSettle();

      expect(find.text("Est-ce l'Ancien ?"), findsNothing);
    });
  });

  group('the wolf camp', () {
    testWidgets('the Wolf-Hound chooses his side, and the wolves step follows', (tester) async {
      final id = await _startedGame(
        repo,
        composition: const {'chien_loup': 1, 'loup_garou': 2, 'villageois': 3},
      );
      await pump(tester, id);

      await identify(tester, ['Ana']);
      expect(find.text('Que choisit le Chien-Loup ? Ce choix est définitif.'), findsOneWidget);
      await tester.tap(find.text('Il rejoint les Loups'));
      await tester.pumpAndSettle();

      expect(find.text('Qui sont les Loups-Garous ?'), findsOneWidget);
      await tester.tap(find.text('Journal'));
      await tester.pumpAndSettle();
      expect(find.text('Ana, Chien-Loup, rejoint les Loups'), findsOneWidget);
    });

    testWidgets('the Wild Child picks a model', (tester) async {
      final id = await _startedGame(
        repo,
        composition: const {'enfant_sauvage': 1, 'loup_garou': 2, 'villageois': 3},
      );
      await pump(tester, id);

      await identify(tester, ['Ana']);
      await tapName(tester, 'Cy');
      await tester.tap(find.text('Son modèle : Cy'));
      await tester.pumpAndSettle();

      expect(find.text('Qui sont les Loups-Garous ?'), findsOneWidget);
    });

    testWidgets('the Cursed Wolf-Father can infect the wolves\' victim', (tester) async {
      final id = await _startedGame(
        repo,
        composition: const {'infect_pere_des_loups': 1, 'loup_garou': 2, 'villageois': 3},
      );
      await pump(tester, id);

      await identify(tester, ['Bo', 'Cy']); // the wolves
      await tapName(tester, 'Di');
      await tester.tap(find.text('Les Loups désignent Di'));
      await tester.pumpAndSettle();
      await identify(tester, ['Ana']); // the Cursed Wolf-Father

      expect(
        find.text("Les Loups ont désigné Di. L'Infect Père des Loups lève-t-il la main ?"),
        findsOneWidget,
      );
      await tester.tap(find.text('Infecter Di'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Journal'));
      await tester.pumpAndSettle();
      expect(find.text("Di est infecté par l'Infect Père des Loups"), findsOneWidget);
    });

    testWidgets('the Cursed Wolf-Father can let the victim be eaten', (tester) async {
      final id = await _startedGame(
        repo,
        composition: const {'infect_pere_des_loups': 1, 'loup_garou': 2, 'villageois': 3},
      );
      await pump(tester, id);

      await identify(tester, ['Bo', 'Cy']);
      await tapName(tester, 'Di');
      await tester.tap(find.text('Les Loups désignent Di'));
      await tester.pumpAndSettle();
      await identify(tester, ['Ana']);
      await tester.tap(find.text("Il n'infecte pas"));
      await tester.pumpAndSettle();

      expect(find.text('Résoudre la nuit'), findsOneWidget);
    });

    testWidgets('the Big Bad Wolf picks a second victim who is not a wolf', (tester) async {
      final id = await _startedGame(
        repo,
        composition: const {'grand_mechant_loup': 1, 'loup_garou': 2, 'villageois': 3},
      );
      await pump(tester, id);

      await identify(tester, ['Bo', 'Cy']);
      await tapName(tester, 'Di');
      await tester.tap(find.text('Les Loups désignent Di'));
      await tester.pumpAndSettle();
      await identify(tester, ['Ana']); // the Big Bad Wolf

      expect(find.text('Quelle est la 2e victime du Grand-Méchant-Loup ?'), findsOneWidget);
      expect(find.text('Bo'), findsNothing); // a wolf
      expect(find.text('Di'), findsNothing); // already the first victim
      await tapName(tester, 'Ed');
      await tester.tap(find.text('Le Grand-Méchant-Loup dévore Ed'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Journal'));
      await tester.pumpAndSettle();
      expect(find.text('Le Grand-Méchant-Loup dévore aussi Ed'), findsOneWidget);
    });

    testWidgets('the White Werewolf is only identified on night 1', (tester) async {
      final id = await _startedGame(
        repo,
        composition: const {'loup_garou_blanc': 1, 'loup_garou': 2, 'villageois': 3},
      );
      await pump(tester, id);

      await identify(tester, ['Bo', 'Cy']);
      await tapName(tester, 'Di');
      await tester.tap(find.text('Les Loups désignent Di'));
      await tester.pumpAndSettle();
      await identify(tester, ['Ana']); // the White Werewolf

      expect(find.text('Quel Loup le Loup-Garou Blanc élimine-t-il ?'), findsNothing);
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      expect(find.text('Résoudre la nuit'), findsOneWidget);
    });

    testWidgets('the wolves cannot pick a player already known as one of the pack', (tester) async {
      final id = await _startedGame(
        repo,
        composition: const {'chien_loup': 1, 'loup_garou': 2, 'villageois': 3},
      );
      await pump(tester, id);

      await identify(tester, ['Ana']); // the Wolf-Hound
      await tester.tap(find.text('Il rejoint les Loups'));
      await tester.pumpAndSettle();
      await identify(tester, ['Bo', 'Cy']);

      expect(find.text('Qui les Loups dévorent-ils ?'), findsOneWidget);
      expect(find.text('Ana'), findsNothing); // the Wolf-Hound who joined them
      expect(find.text('Bo'), findsNothing);
      expect(find.text('Di'), findsOneWidget);
    });
  });

  group('the Fox', () {
    const comp = {'renard': 1, 'loup_garou': 2, 'villageois': 3};

    testWidgets('names the three he sniffs, and a "no wolf" answer ends his power', (tester) async {
      final id = await _startedGame(repo, composition: comp);
      await pump(tester, id);

      await identify(tester, ['Ana']); // Fox = Ana
      await tapName(tester, 'Cy');
      await tester.tap(find.text('Flairer autour de Cy'));
      await tester.pumpAndSettle();

      expect(find.text('Le Renard flaire Bo, Cy et Di.'), findsOneWidget);
      expect(find.textContaining("aucun Loup."), findsOneWidget); // no wolf known yet
      expect(find.text('Sans Loup, le Renard perd son pouvoir pour de bon.'), findsOneWidget);

      await tester.tap(find.text('Non, aucun Loup'));
      await tester.pumpAndSettle();

      // on to the wolves; the journal remembers the lost power
      expect(find.text('Qui sont les Loups-Garous ?'), findsOneWidget);
      await tester.tap(find.text('Journal'));
      await tester.pumpAndSettle();
      expect(
        find.text('Le Renard flaire autour de Cy : aucun Loup, il perd son pouvoir'),
        findsOneWidget,
      );
    });

    testWidgets('a wolf among the three keeps his power', (tester) async {
      final id = await _startedGame(repo, composition: comp);
      await pump(tester, id);

      await identify(tester, ['Ana']);
      await tapName(tester, 'Cy');
      await tester.tap(find.text('Flairer autour de Cy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Oui, il y a un Loup'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Journal'));
      await tester.pumpAndSettle();
      expect(find.text('Le Renard flaire autour de Cy : un Loup'), findsOneWidget);
    });

    testWidgets('can be passed without sniffing', (tester) async {
      final id = await _startedGame(repo, composition: comp);
      await pump(tester, id);

      await identify(tester, ['Ana']);
      await tester.tap(find.text('Passer ce rôle'));
      await tester.pumpAndSettle();

      expect(find.text('Qui sont les Loups-Garous ?'), findsOneWidget);
    });
  });

  group('the Two Sisters and the Bear Tamer', () {
    testWidgets('the Sisters are identified together, meet, and the call can be passed', (
      tester,
    ) async {
      final id = await _startedGame(
        repo,
        composition: const {'deux_soeurs': 2, 'loup_garou': 2, 'villageois': 2},
      );
      await pump(tester, id);

      expect(find.text('Qui sont les Deux Sœurs ?'), findsOneWidget);
      await identify(tester, ['Ana', 'Bo']);
      expect(find.text('Elles se sont reconnues'), findsOneWidget);
      expect(find.text('Passer ce rôle'), findsOneWidget);

      await tester.tap(find.text('Elles se sont reconnues'));
      await tester.pumpAndSettle();
      expect(find.text('Qui sont les Loups-Garous ?'), findsOneWidget);
    });

    testWidgets('the Bear Tamer is only made known', (tester) async {
      final id = await _startedGame(
        repo,
        composition: const {'montreur_d_ours': 1, 'loup_garou': 2, 'villageois': 3},
      );
      await pump(tester, id);

      await identify(tester, ['Cy']);
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(find.text('Qui sont les Loups-Garous ?'), findsOneWidget);
    });
  });

  group('a drawn Voleur reserve', () {
    const comp = {'voleur': 1, 'loup_garou': 2, 'sorciere': 1, 'villageois': 2};

    /// Notes the two leftover cards through the picker sheet.
    Future<void> noteReserve(WidgetTester tester, String first, String second) async {
      for (final role in [first, second]) {
        await tester.tap(find.text('Choisir une carte').first);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, role));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Valider ces 2 cartes'));
      await tester.pumpAndSettle();
    }

    testWidgets('is asked for first, and the leftover cards are offered to the Voleur', (
      tester,
    ) async {
      final id = await _startedGame(repo, composition: comp);
      await pump(tester, id);

      expect(find.text('Les 2 cartes restantes'), findsOneWidget);
      expect(find.text('Valider ces 2 cartes'), findsOneWidget);
      // Nothing to confirm until both cards are noted.
      expect(
        tester.widget<AppButton>(find.widgetWithText(AppButton, 'Valider ces 2 cartes')).onPressed,
        isNull,
      );

      await noteReserve(tester, 'Sorcière', 'Loup-Garou');

      // Noted: on to who the Voleur is, then his choice between exactly those two cards.
      expect(find.text('Les 2 cartes restantes'), findsNothing);
      await identify(tester, ['Ana']);
      expect(find.text('Sorcière'), findsOneWidget);
      expect(find.text('Loup-Garou'), findsOneWidget);
      expect(find.text('Simple Villageois'), findsNothing);
    });

    testWidgets('then the Voleur is identified and picks one of the noted cards', (tester) async {
      final id = await _startedGame(repo, composition: comp);
      await pump(tester, id);

      await noteReserve(tester, 'Sorcière', 'Simple Villageois');
      await identify(tester, ['Ana']); // Voleur = Ana

      expect(find.text('Les deux cartes de la pioche'), findsOneWidget);
      expect(find.text('Il garde sa carte'), findsOneWidget);
      await tester.tap(find.text('Sorcière'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Le Voleur prend la Sorcière'));
      await tester.pumpAndSettle();

      // The Sorcière's card was in the middle: no one else to find, straight to the wolves.
      expect(find.textContaining('Qui sont'), findsWidgets);
      expect(find.text('Qui est la Sorcière ?'), findsNothing);
    });

    testWidgets('two wolves leave the Voleur no choice but to take one', (tester) async {
      final id = await _startedGame(repo, composition: comp);
      await pump(tester, id);

      await noteReserve(tester, 'Loup-Garou', 'Loup-Garou');
      await identify(tester, ['Ana']);

      expect(find.textContaining('Les deux cartes sont des Loups-Garous'), findsOneWidget);
      expect(find.text('Il garde sa carte'), findsNothing);
    });

    testWidgets('a role whose only card is in the middle is called with nobody to act', (
      tester,
    ) async {
      final id = await _startedGame(
        repo,
        composition: const {'voleur': 1, 'loup_garou': 2, 'sorciere': 1, 'villageois': 2},
      );
      await pump(tester, id);

      await noteReserve(tester, 'Sorcière', 'Simple Villageois');
      await identify(tester, ['Ana']); // Voleur = Ana
      await tester.tap(find.text('Il garde sa carte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Le Voleur garde sa carte'));
      await tester.pumpAndSettle();
      await identify(tester, ['Bo', 'Cy']); // the wolves
      await tapName(tester, 'Di');
      await tester.tap(find.text('Les Loups désignent Di'));
      await tester.pumpAndSettle();

      // The Sorcière step is there to be called, but no one is asked who she is.
      expect(find.text('Qui est la Sorcière ?'), findsNothing);
      expect(find.text('Passer ce rôle'), findsOneWidget);
    });

    testWidgets('the reserve can be noted later', (tester) async {
      final id = await _startedGame(repo, composition: comp);
      await pump(tester, id);

      await tester.tap(find.text('Je noterai plus tard'));
      await tester.pumpAndSettle();

      expect(find.text('Les 2 cartes restantes'), findsNothing);
    });
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

  testWidgets(
    'a Voleur who steals a Loup is no longer offered as a Voyante note option',
    (tester) async {
      final id = await _startedGame(
        repo,
        composition: const {
          'voleur': 1,
          'voyante': 1,
          'loup_garou': 2,
          'villageois': 2,
        },
        reserveRoleIds: const ['loup_garou', 'chasseur'],
      );
      await pump(tester, id);

      await identify(tester, ['Ana']); // Voleur = Ana
      await tester.tap(find.text('Loup-Garou'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Le Voleur prend le Loup-Garou'));
      await tester.pumpAndSettle();

      await identify(tester, ['Bo']); // Voyante = Bo
      expect(find.text('Qui la Voyante observe-t-elle ?'), findsOneWidget);

      // Cy's card isn't on record -> the note picker opens.
      await tapName(tester, 'Cy');
      await tester.tap(find.text('La Voyante observe Cy'));
      await tester.pumpAndSettle();
      expect(find.text('La carte de Cy'), findsOneWidget);

      // The one Voleur card was already spent by Ana's swap into Loup-Garou - it must not
      // be offered again, even though no roster entry carries roleId 'voleur' any more.
      expect(find.text('Voleur'), findsNothing);
      // The still-undealt roles remain offered: 1 more Loup-Garou (Ana took the other) and
      // both Villageois.
      expect(find.text('Loup-Garou'), findsOneWidget);
      expect(find.text('Simple Villageois'), findsOneWidget);
    },
  );

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
