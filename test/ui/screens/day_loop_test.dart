import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/data/database/app_database.dart';
import 'package:loup_garou_mj/data/repositories/drift_game_repository.dart';
import 'package:loup_garou_mj/state/providers/game_repository_provider.dart';
import 'package:loup_garou_mj/ui/theme/app_icons.dart';

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
    await tap(tester, 'Passer ce rôle'); // skip the Voyante's look
    await identify(tester, ['Bo', 'Cy']);
    await tester.tap(find.text(victim));
    await tester.pumpAndSettle();
    await tap(tester, 'Les Loups désignent $victim');
    await identify(tester, ['Di']);
    await tap(tester, 'Terminer le tour de la Sorcière');
    await tap(tester, 'Résoudre la nuit');
  }

  group('the Knight with the Rusty Sword', () {
    const comp = {'chevalier': 1, 'loup_garou': 2, 'villageois': 3};

    Future<void> knightEaten(WidgetTester tester) async {
      await identify(tester, ['Cy', 'Ed']); // the wolves
      await tester.tap(find.text('Ana'));
      await tester.pumpAndSettle();
      await tap(tester, 'Les Loups désignent Ana');
      await tap(tester, 'Résoudre la nuit');
      // Ana's card is turned over: the Knight.
      await tap(tester, "Chevalier à l'Épée Rouillée");
      await tap(tester, "Ana était le Chevalier à l'Épée Rouillée");
    }

    testWidgets('asks which wolf is diseased, suggesting the first one to his left', (tester) async {
      final id = await _startedGame(repo, comp);
      await pump(tester, id);
      await knightEaten(tester);

      expect(find.text('Le Chevalier est dévoré'), findsOneWidget);
      // Ana is seat 1: her left, going back round the table, meets Ed (seat 5) before Cy (seat 3).
      expect(find.text("D'après les rôles notés : Ed."), findsOneWidget);
      expect(find.textContaining('au début de la nuit prochaine'), findsOneWidget);

      await tester.tap(find.text('Ed'));
      await tester.pumpAndSettle();
      await tap(tester, 'Ed est malade');

      // back to the day, the sickness is written down
      expect(find.text('Quel Loup est malade ?'), findsNothing);
      await tap(tester, 'Journal');
      expect(find.text('Le Chevalier laisse Ed malade'), findsOneWidget);
    });

    testWidgets('can be told there is no wolf to wound', (tester) async {
      final id = await _startedGame(repo, comp);
      await pump(tester, id);
      await knightEaten(tester);

      await tap(tester, 'Aucun Loup à atteindre');

      expect(find.text('Quel Loup est malade ?'), findsNothing);
    });
  });

  group('the growl of the Bear Tamer', () {
    const comp = {'montreur_d_ours': 1, 'loup_garou': 2, 'villageois': 3};

    /// Night 1: Bear Tamer = Cy (between Bo and Di), wolves = Bo + Ed, they eat Fi.
    Future<void> nightWithBear(WidgetTester tester, {required List<String> wolves}) async {
      await identify(tester, ['Cy']);
      await tap(tester, 'Continuer');
      await identify(tester, wolves);
      await tester.tap(find.text('Fi'));
      await tester.pumpAndSettle();
      await tap(tester, 'Les Loups désignent Fi');
      await tap(tester, 'Résoudre la nuit');
      while (find.text('Je ne note pas').evaluate().isNotEmpty) {
        await tap(tester, 'Je ne note pas');
      }
    }

    testWidgets('comes after the recap and is journalled when he growls', (tester) async {
      final id = await _startedGame(repo, comp);
      await pump(tester, id);
      await nightWithBear(tester, wolves: ['Bo', 'Ed']);

      await tap(tester, "Le grognement du Montreur d'Ours");
      expect(
        find.text("Cy est le Montreur d'Ours. Ses voisins vivants : Bo et Di."),
        findsOneWidget,
      );
      expect(find.textContaining('un de ses voisins est un Loup : il grogne'), findsOneWidget);

      await tap(tester, 'Je grogne');
      expect(find.text('Qui est élu ?'), findsOneWidget); // on to the Capitaine

      await tap(tester, 'Journal');
      expect(find.text("Le Montreur d'Ours grogne"), findsOneWidget);
    });

    testWidgets('says there is none when no neighbour is a wolf, and writes nothing', (
      tester,
    ) async {
      final id = await _startedGame(repo, comp);
      await pump(tester, id);
      await nightWithBear(tester, wolves: ['Ana', 'Ed']);

      await tap(tester, "Le grognement du Montreur d'Ours");
      expect(find.textContaining("aucun de ses voisins n'est un Loup"), findsOneWidget);

      await tap(tester, 'Pas de grognement');
      expect(find.text('Qui est élu ?'), findsOneWidget);
      await tap(tester, 'Journal');
      expect(find.text("Le Montreur d'Ours grogne"), findsNothing);
    });

    testWidgets('lets the MJ growl against what the app knows', (tester) async {
      final id = await _startedGame(repo, comp);
      await pump(tester, id);
      await nightWithBear(tester, wolves: ['Ana', 'Ed']);

      await tap(tester, "Le grognement du Montreur d'Ours");
      await tap(tester, 'Je grogne');

      await tap(tester, 'Journal');
      expect(find.text("Le Montreur d'Ours grogne"), findsOneWidget);
    });
  });

  testWidgets('recap CTA -> captain election -> vote -> next night', (tester) async {
    final id = await _startedGame(repo, const {
      'loup_garou': 2,
      'voyante': 1,
      'sorciere': 1,
      'villageois': 2,
    });
    await pump(tester, id);
    await playNight1(tester, victim: 'Ana'); // Ana is the identified Voyante -> no reveal

    // the day recap - Ana was the identified Voyante, so her card is spelled out
    expect(find.text('JOUR 1 SE LÈVE'), findsOneWidget);
    expect(find.text('Victime des Loups'), findsOneWidget);
    expect(find.text('Était la Voyante'), findsOneWidget);
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
    expect(find.text('NUIT 2'), findsOneWidget);
    // the Loups are already known - straight to the action, no re-identification
    expect(find.text('Qui les Loups dévorent-ils ?'), findsOneWidget);
    expect(find.text('Enregistrer'), findsNothing);

    await tap(tester, 'Journal');
    expect(find.text('Bo est Capitaine'), findsOneWidget);
    expect(find.text('Le village élimine Cy'), findsOneWidget);
  });

  testWidgets('Cupidon pairs two players', (tester) async {
    final id = await _startedGame(repo, const {
      'loup_garou': 2,
      'cupidon': 1,
      'voyante': 1,
      'sorciere': 1,
      'villageois': 1,
    });
    await pump(tester, id);

    // wake order: Cupidon, Voyante, Loups, Sorcière
    await identify(tester, ['Ana']); // Cupidon
    expect(find.text('Qui sont les amoureux ?'), findsOneWidget);
    await tester.tap(find.text('Bo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cy'));
    await tester.pumpAndSettle();
    await tap(tester, 'Cupidon unit Bo et Cy');

    // advanced to the Voyante
    expect(find.text('Qui est Voyante ?'), findsOneWidget);

    await tap(tester, 'Journal');
    expect(find.text('Cupidon unit Bo et Cy'), findsOneWidget);
  });

  testWidgets('a lover who dies of grief: the panel names the couple and the card', (tester) async {
    final id = await _startedGame(repo, const {
      'loup_garou': 2,
      'cupidon': 1,
      'voyante': 1,
      'villageois': 2,
    });
    await pump(tester, id);

    // wake order: Cupidon, Voyante, Loups
    await identify(tester, ['Ana']); // Cupidon pairs the two villagers
    await tester.tap(find.text('Di'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ed'));
    await tester.pumpAndSettle();
    await tap(tester, 'Cupidon unit Di et Ed');

    // Voyante = Fi, notes Ed as a Villageois so his card is on record
    await identify(tester, ['Fi']);
    await tester.tap(find.text('Ed'));
    await tester.pumpAndSettle();
    await tap(tester, 'La Voyante observe Ed');
    await tap(tester, 'Simple Villageois');
    await tap(tester, 'Ed est le Simple Villageois');
    await tap(tester, 'Continuer');

    // Loups eat Di, the other lover
    await identify(tester, ['Bo', 'Cy']);
    await tester.tap(find.text('Di'));
    await tester.pumpAndSettle();
    await tap(tester, 'Les Loups désignent Di');
    await tap(tester, 'Résoudre la nuit');

    // Di was never identified -> reveal panel; leave her card unnoted
    await tap(tester, 'Je ne note pas');

    // the lovers-ack panel for Ed names the partner and turns his card over
    expect(find.text('Amoureux de Di'), findsOneWidget);
    expect(find.text('Sa carte'), findsOneWidget);
    expect(find.textContaining("Di n'est plus"), findsOneWidget);
    await tap(tester, 'Compris');

    // day recap: Ed's card spelled out, Di's marked unrevealed
    expect(find.text('JOUR 1 SE LÈVE'), findsOneWidget);
    expect(find.text('Était le Simple Villageois'), findsOneWidget);
    expect(find.text('Rôle non révélé'), findsOneWidget);
  });

  testWidgets('the aide-memoire opens from the night header on later nights', (tester) async {
    final id = await _startedGame(repo, const {
      'loup_garou': 2,
      'voyante': 1,
      'sorciere': 1,
      'villageois': 2,
    });
    await pump(tester, id);
    await playNight1(tester, victim: 'Ana');
    await tap(tester, 'Élire le Capitaine');
    await tap(tester, 'Pas de Capitaine cette partie');
    await tap(tester, 'Égalité, personne n\'est éliminé');
    await tap(tester, 'Commencer la nuit 2');

    expect(find.text('NUIT 2'), findsOneWidget);
    await tester.tap(find.byIcon(AppIcons.help));
    await tester.pumpAndSettle();
    expect(find.text('Ordre de réveil'), findsOneWidget);
    expect(find.text('Sorcière'), findsWidgets);
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
