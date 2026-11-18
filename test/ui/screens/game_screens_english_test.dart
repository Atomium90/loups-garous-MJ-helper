import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/data/database/app_database.dart';
import 'package:loup_garou_mj/data/repositories/drift_game_repository.dart';
import 'package:loup_garou_mj/state/providers/game_repository_provider.dart';
import 'package:loup_garou_mj/ui/theme/app_icons.dart';
import 'package:material_ui/material_ui.dart' show Icons;

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

  /// Taps each of [texts] in turn.
  Future<void> tapAll(WidgetTester tester, List<String> texts) async {
    for (final text in texts) {
      await tester.tap(find.text(text));
      await tester.pumpAndSettle();
    }
  }

  /// Checks that each of [texts] is on screen exactly once.
  void see(List<String> texts) {
    for (final text in texts) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
  }

  testWidgets('night 1, the day recap, the Captain, the vote and the journal', (tester) async {
    await startInEnglish(tester, const {'loup_garou': 1, 'voyante': 1, 'villageois': 3});

    // the tab bar and the night header, then the Seer: who holds the card, who she looks at
    see(['Script', 'NIGHT 1', 'Who has the Seer card?', '0 of 1', 'Pick 1 player']);
    await tapAll(tester, ['Ana', 'Save']);
    see(['Who does the Seer look at?']);

    // the Werewolf
    await tapAll(tester, ['Skip this role', 'Bo', 'Save']);
    see(['Who do the Werewolves devour?']);
    await tapAll(tester, ['Ana', 'The Werewolves pick Ana']);
    see(['Every role has played.']);
    await tapAll(tester, ['Resolve the night']);

    // the day recap: Ana was the identified Seer, so her card is spelled out
    see(['DAY 1 BEGINS', 'Tonight, the village lost', 'Was the Seer', 'Victim of the Wolves']);
    await tapAll(tester, ['Elect the Captain']);

    see(['The Captain', 'Who is elected?']);
    await tapAll(tester, ['Bo', 'Bo is Captain']);

    see(['Who is eliminated?', 'Tie, nobody is eliminated']);
    expect(find.textContaining("Bo's vote counts double"), findsOneWidget);
    await tapAll(tester, ['Cy', 'The village eliminates Cy']);

    // Cy's card was never noted: the reveal panel comes first
    see(['Eliminated night 1', 'What was their card?', '3 left']);
    await tapAll(tester, ['Villager', 'Cy was the Villager']);

    see(['The day is over.', 'Start night 2']);

    // the village and the journal
    await tapAll(tester, ['Village']);
    see(['3 of 5 alive', 'ELIMINATED', 'End the game']);

    await tapAll(tester, ['Journal']);
    see([
      'DAY 1',
      'NIGHT 1',
      'The village eliminates Cy',
      'Bo is Captain',
      'The Werewolves pick Ana',
    ]);
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
    await tester.tap(find.byIcon(AppIcons.help));
    await tester.pumpAndSettle();
    see(['Wake-up order', 'Your composition, in order']);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // Cupid, then the Seer looks at nobody and the Werewolf picks Ana
    see(['Who has the Cupid card?']);
    await tapAll(tester, ['Ana', 'Save']);
    see(['Who are the lovers?', 'Pick two players']);
    await tapAll(tester, ['Bo', 'Cy', 'Cupid pairs Bo and Cy']);
    await tapAll(tester, ['Di', 'Save', 'Skip this role', 'Ed', 'Save']);
    await tapAll(tester, ['Ana', 'The Werewolves pick Ana']);

    // the Witch poisons Cy, who is Bo's lover
    await tapAll(tester, ['Bo', 'Save']);
    see(['Life available', 'Death available', "The Werewolves' victim tonight"]);
    await tapAll(tester, ['She poisons…']);
    see(['Who does the Witch poison?']);
    await tapAll(tester, ['Cy', 'She poisons Cy']);
    see(['Death used']);
    await tapAll(tester, ["End the Witch's turn", 'Resolve the night']);

    // The dead players' cards were never noted, so the first one is asked for before the day
    see(['Eliminated night 1', 'What was their card?', "I won't note it"]);
  });
}
