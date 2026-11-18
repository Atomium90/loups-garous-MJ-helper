import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/data/database/app_database.dart';
import 'package:loup_garou_mj/data/repositories/drift_game_repository.dart';
import 'package:loup_garou_mj/state/providers/game_repository_provider.dart';
import 'package:loup_garou_mj/ui/theme/app_icons.dart';

import '../../support/pump_app.dart';

/// A night and a day of a game, played in English: a smoke test that every text on the way
/// comes from the English messages.
void main() {
  late AppDatabase db;
  late DriftGameRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftGameRepository(db);
    addTearDown(db.close);
  });

  /// Starts a game of Ana, Bo, Cy, Di and Ed with [roleCounts] and opens it in English.
  Future<void> startInEnglish(WidgetTester tester, Map<String, int> roleCounts) async {
    final id = await repo.createGame(initialPlayerCount: 5);
    await repo.saveComposition(gameId: id, playerCount: 5, roleCounts: roleCounts);
    await repo.savePlayerNames(gameId: id, names: const ['Ana', 'Bo', 'Cy', 'Di', 'Ed']);
    await repo.startGame(id);
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(repo)],
      initialLocation: '/games/$id/game',
      locale: const Locale('en'),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapIcon(WidgetTester tester, IconData icon) async {
    await tester.tap(find.byIcon(icon));
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('night 1, the day recap, the Captain, the vote and the journal', (tester) async {
    await startInEnglish(tester, const {'loup_garou': 1, 'voyante': 1, 'villageois': 3});

    // the tab bar and the night header
    expect(find.text('Script'), findsOneWidget);
    expect(find.text('NIGHT 1'), findsOneWidget);

    // the Seer: who holds the card, then who she looks at
    expect(find.text('Who has the Seer card?'), findsOneWidget);
    expect(find.text('0 of 1'), findsOneWidget);
    expect(find.text('Pick 1 player'), findsOneWidget);
    await tapText(tester, 'Ana');
    await tapText(tester, 'Save');
    expect(find.text('Who does the Seer look at?'), findsOneWidget);
    await tapText(tester, 'Skip this role');

    // the Werewolf
    expect(find.text('Who has the Werewolf card?'), findsOneWidget);
    await tapText(tester, 'Bo');
    await tapText(tester, 'Save');
    expect(find.text('Who do the Werewolves devour?'), findsOneWidget);
    await tapText(tester, 'Ana');
    await tapText(tester, 'The Werewolves pick Ana');
    expect(find.text('Every role has played.'), findsOneWidget);
    await tapText(tester, 'Resolve the night');

    // the day recap: Ana was the identified Seer, so her card is spelled out
    expect(find.text('DAY 1 BEGINS'), findsOneWidget);
    expect(find.text('Tonight, the village lost'), findsOneWidget);
    expect(find.text('Was the Seer'), findsOneWidget);
    expect(find.text('Victim of the Wolves'), findsOneWidget);
    await tapText(tester, 'Elect the Captain');

    expect(find.text('The Captain'), findsOneWidget);
    expect(find.text('Who is elected?'), findsOneWidget);
    await tapText(tester, 'Bo');
    await tapText(tester, 'Bo is Captain');

    expect(find.text('Who is eliminated?'), findsOneWidget);
    expect(find.textContaining("Bo's vote counts double"), findsOneWidget);
    expect(find.text('Tie, nobody is eliminated'), findsOneWidget);
    await tapText(tester, 'Cy');
    await tapText(tester, 'The village eliminates Cy');


    // Cy's card was never noted: the reveal panel comes first
    expect(find.text('Eliminated night 1'), findsOneWidget);
    expect(find.text('What was their card?'), findsOneWidget);
    expect(find.text('3 left'), findsOneWidget);
    await tapText(tester, 'Villager');
    await tapText(tester, 'Cy was the Villager');

    expect(find.text('The day is over.'), findsOneWidget);
    expect(find.text('Start night 2'), findsOneWidget);

    // the village and the journal
    await tapText(tester, 'Village');
    expect(find.text('3 of 5 alive'), findsOneWidget);
    expect(find.text('ELIMINATED'), findsOneWidget);
    expect(find.text('End the game'), findsOneWidget);

    await tapText(tester, 'Journal');
    expect(find.text('DAY 1'), findsOneWidget);
    expect(find.text('NIGHT 1'), findsOneWidget);
    expect(find.text('The village eliminates Cy'), findsOneWidget);
    expect(find.text('Bo is Captain'), findsOneWidget);
    expect(find.text('The Werewolves pick Ana'), findsOneWidget);
  });

  testWidgets('Cupid, the Witch and the quick reference', (tester) async {
    await startInEnglish(tester, const {
        'loup_garou': 1,
        'cupidon': 1,
        'voyante': 1,
        'sorciere': 1,
        'villageois': 1,
      });

    // the quick reference sheet, opened from the header
    await tapIcon(tester, AppIcons.help);
    expect(find.text('Wake-up order'), findsOneWidget);
    expect(find.text('Your composition, in order'), findsOneWidget);
    await tapIcon(tester, Icons.close);

    // Cupid
    expect(find.text('Who has the Cupid card?'), findsOneWidget);
    await tapText(tester, 'Ana');
    await tapText(tester, 'Save');
    expect(find.text('Who are the lovers?'), findsOneWidget);
    expect(find.text('Pick two players'), findsOneWidget);
    await tapText(tester, 'Bo');
    await tapText(tester, 'Cy');
    await tapText(tester, 'Cupid pairs Bo and Cy');

    // the Seer looks at nobody, the Werewolf picks Ana, then the Witch
    await tapText(tester, 'Di');
    await tapText(tester, 'Save');
    await tapText(tester, 'Skip this role');
    await tapText(tester, 'Ed');
    await tapText(tester, 'Save');
    await tapText(tester, 'Ana');
    await tapText(tester, 'The Werewolves pick Ana');
    await tapText(tester, 'Bo');
    await tapText(tester, 'Save');
    expect(find.text('Life available'), findsOneWidget);
    expect(find.text('Death available'), findsOneWidget);
    expect(find.text("The Werewolves' victim tonight"), findsOneWidget);
    await tapText(tester, 'She poisons…');
    expect(find.text('Who does the Witch poison?'), findsOneWidget);
    await tapText(tester, 'Cy');
    await tapText(tester, 'She poisons Cy');
    expect(find.text('Death used'), findsOneWidget);
    await tapText(tester, "End the Witch's turn");
    await tapText(tester, 'Resolve the night');

    // The dead players' cards were never noted, so the first one is asked for before the day
    expect(find.text('Eliminated night 1'), findsOneWidget);
    expect(find.text('What was their card?'), findsOneWidget);
    expect(find.text("I won't note it"), findsOneWidget);
  });
}
