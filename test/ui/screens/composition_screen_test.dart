import 'dart:math';

import 'package:flutter/material.dart';
// `Override` (used below) isn't in flutter_riverpod.dart's own export list - see
// test/support/pump_app.dart for the same note.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/data/database/app_database.dart';
import 'package:loup_garou_mj/data/models/game_status.dart';
import 'package:loup_garou_mj/state/composition/composition_advisor_provider.dart';
import 'package:loup_garou_mj/state/providers/game_repository_provider.dart';
import 'package:loup_garou_mj/ui/screens/composition/composition_screen.dart';
import 'package:loup_garou_mj/ui/screens/home/home_screen.dart';
import 'package:loup_garou_mj/ui/screens/players/players_screen.dart';
import 'package:loup_garou_mj/ui/theme/app_icons.dart';
import 'package:loup_garou_mj/ui/widgets/app_button.dart';
import 'package:loup_garou_mj/ui/widgets/app_chip.dart';
import 'package:loup_garou_mj/ui/widgets/app_stepper.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../support/fake_game_repository.dart';
import '../../support/pump_app.dart';

/// A seeded advisor override so suggestion-card assertions don't depend on real randomness -
/// moot for the base registry anyway (see composition_advisor_test.dart: it never has a
/// surplus tier to shuffle within the 8-18 player range), but explicit is cheap.
Override _seededAdvisorOverride() => compositionAdvisorProvider.overrideWithValue(
  CompositionAdvisor(RoleRegistry.base, random: Random(1)),
);

/// A fresh draft game (status setup, no composition chosen yet).
Game _draftGame({required int id, required int playerCount}) {
  final now = DateTime.now();
  return Game(
    id: id,
    createdAt: now,
    updatedAt: now,
    playerCount: playerCount,
    status: GameStatus.setup,
  );
}

/// [CompositionScreen] always renders exactly 3 [AppStepper]s in this fixed order: the
/// player-count stepper, then (within the role list) villageois's, then loup_garou's - both
/// scaling roles always render their stepper regardless of current count. This mirrors
/// `RoleRegistry.base.roles`' declared order filtered by team, not layout happenstance.
Finder _stepperPlusAt(int index) =>
    find.descendant(of: find.byType(AppStepper).at(index), matching: find.text('+'));
Finder _stepperMinusAt(int index) =>
    find.descendant(of: find.byType(AppStepper).at(index), matching: find.text('−'));

AppButton _launchButton(WidgetTester tester) =>
    tester.widget<AppButton>(find.widgetWithText(AppButton, 'Lancer la partie'));

void main() {
  testWidgets(
    "player-count stepper updates the footer, inert at the box's 8-18 bounds",
    (tester) async {
      final repository = FakeGameRepository(
        initialGames: [_draftGame(id: 1, playerCount: 8)],
      );
      await pumpScreen(
        tester,
        const CompositionScreen(gameId: 1),
        overrides: [gameRepositoryProvider.overrideWithValue(repository)],
      );
      await tester.pumpAndSettle();

      // textContaining('rôles pour N joueurs') rather than just 'pour N joueurs': the
      // suggestion card's own "Suggestion pour N joueurs" heading otherwise also matches.
      expect(find.textContaining('rôles pour 8 joueurs'), findsOneWidget);
      await tester.tap(_stepperMinusAt(0));
      await tester.pump();
      expect(find.textContaining('rôles pour 8 joueurs'), findsOneWidget);

      await tester.tap(_stepperPlusAt(0));
      await tester.pump();
      expect(find.textContaining('rôles pour 9 joueurs'), findsOneWidget);
    },
  );

  testWidgets('player-count stepper is inert at 18 (max)', (tester) async {
    final repository = FakeGameRepository(initialGames: [_draftGame(id: 1, playerCount: 18)]);
    await pumpScreen(
      tester,
      const CompositionScreen(gameId: 1),
      overrides: [gameRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    await tester.tap(_stepperPlusAt(0));
    await tester.pump();
    expect(find.textContaining('rôles pour 18 joueurs'), findsOneWidget);
  });

  testWidgets('tapping a singleton role chip toggles it and updates the footer count', (
    tester,
  ) async {
    final repository = FakeGameRepository(initialGames: [_draftGame(id: 1, playerCount: 8)]);
    await pumpScreen(
      tester,
      const CompositionScreen(gameId: 1),
      overrides: [gameRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    expect(find.text('0 rôles pour 8 joueurs'), findsOneWidget);
    await tester.tap(find.text('Voyante'));
    await tester.pump();
    expect(find.text('1 rôles pour 8 joueurs'), findsOneWidget);

    await tester.tap(find.text('Voyante'));
    await tester.pump();
    expect(find.text('0 rôles pour 8 joueurs'), findsOneWidget);
  });

  testWidgets('the loup_garou inline stepper increments its count and the footer', (
    tester,
  ) async {
    final repository = FakeGameRepository(initialGames: [_draftGame(id: 1, playerCount: 8)]);
    await pumpScreen(
      tester,
      const CompositionScreen(gameId: 1),
      overrides: [gameRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    await tester.tap(_stepperPlusAt(2)); // player-count(0), villageois(1), loup_garou(2)
    await tester.pump();
    expect(find.text('1 rôles pour 8 joueurs'), findsOneWidget);

    await tester.tap(_stepperPlusAt(2));
    await tester.pump();
    expect(find.text('2 rôles pour 8 joueurs'), findsOneWidget);
  });

  testWidgets(
    'primary button is active until over-assigned; Compo complète only at remaining 0',
    (tester) async {
      final repository = FakeGameRepository(initialGames: [_draftGame(id: 1, playerCount: 2)]);
      await pumpScreen(
        tester,
        const CompositionScreen(gameId: 1),
        overrides: [gameRepositoryProvider.overrideWithValue(repository)],
      );
      await tester.pumpAndSettle();

      expect(_launchButton(tester).onPressed, isNotNull);
      expect(find.text('Compo complète'), findsNothing);

      // loup_garou x2 (max = playerCount = 2): remaining 0, exactly complete.
      await tester.tap(_stepperPlusAt(2));
      await tester.pump();
      await tester.tap(_stepperPlusAt(2));
      await tester.pump();
      expect(find.text('Compo complète'), findsOneWidget);
      expect(_launchButton(tester).onPressed, isNotNull);

      // A singleton chip isn't capped by remaining: pushes assignedCount to 3, remaining -1.
      await tester.tap(find.text('Voyante'));
      await tester.pump();
      expect(find.text('Compo complète'), findsNothing);
      expect(_launchButton(tester).onPressed, isNull);
    },
  );

  testWidgets(
    'Lancer la partie commits the composition (with the villageois top-up) and opens the players screen',
    (tester) async {
      final repository = FakeGameRepository();
      await pumpAppRouter(
        tester,
        overrides: [gameRepositoryProvider.overrideWithValue(repository)],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nouvelle partie'));
      await tester.pumpAndSettle();
      expect(find.byType(CompositionScreen), findsOneWidget);

      await tester.tap(_stepperPlusAt(2)); // loup_garou +1
      await tester.pump();
      await tester.tap(find.text('Lancer la partie'));
      await tester.pumpAndSettle();

      final saved = repository.allGames.single;
      // Committing the composition doesn't start the game: naming and the deal are
      // still setup, and a blank roster gets seeded, sized to the player count.
      expect(saved.status, GameStatus.setup);
      expect(repository.rosterOf(saved.id), hasLength(8));
      // FakeGameRepository.createGame()'s default playerCount is 8; 1 wolf assigned leaves 7
      // remaining, silently topped up as villageois - matches CompositionEditor.commit()'s
      // documented behaviour.
      expect(saved.compositionJson, {'loup_garou': 1, 'villageois': 7});
      // ...and it moves on to "Les joueurs", not back home.
      expect(find.byType(PlayersScreen), findsOneWidget);
      expect(find.text('Les joueurs'), findsOneWidget);
    },
  );

  testWidgets('the Voleur reveals the reserve section and gates "Lancer la partie"', (
    tester,
  ) async {
    final repository = FakeGameRepository(initialGames: [_draftGame(id: 1, playerCount: 8)]);
    await pumpScreen(
      tester,
      const CompositionScreen(gameId: 1),
      overrides: [gameRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    expect(find.text('Réserve du Voleur'), findsNothing);

    await tester.tap(find.text('Voleur'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Réserve du Voleur'));
    expect(find.text('Réserve du Voleur'), findsOneWidget);
    // Reserve incomplete -> launch disabled + hint shown.
    expect(_launchButton(tester).onPressed, isNull);
    expect(find.text('Choisissez les 2 cartes de réserve du Voleur'), findsOneWidget);

    // Fill both slots via the picker sheet (two distinct singleton roles).
    for (final role in ['Cupidon', 'Sorcière']) {
      await tester.ensureVisible(find.text('Choisir une carte').first);
      await tester.tap(find.text('Choisir une carte').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, role));
      await tester.pumpAndSettle();
    }

    expect(_launchButton(tester).onPressed, isNotNull);
    expect(find.text('Choisissez les 2 cartes de réserve du Voleur'), findsNothing);
  });

  testWidgets('a role fully claimed by the reserve is disabled with an "en réserve" note', (
    tester,
  ) async {
    final repository = FakeGameRepository(initialGames: [_draftGame(id: 1, playerCount: 8)]);
    await pumpScreen(
      tester,
      const CompositionScreen(gameId: 1),
      overrides: [gameRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Voleur'));
    await tester.pump();
    await tester.ensureVisible(find.text('Choisir une carte').first);
    await tester.tap(find.text('Choisir une carte').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Sorcière'));
    await tester.pumpAndSettle();

    expect(find.text('en réserve'), findsOneWidget);
    expect(find.text('1 rôles pour 8 joueurs'), findsOneWidget); // just the Voleur

    // Tapping the disabled Sorcière chip does nothing (count stays at 1).
    await tester.tap(
      find.descendant(of: find.byType(AppChip), matching: find.text('Sorcière')),
    );
    await tester.pump();
    expect(find.text('1 rôles pour 8 joueurs'), findsOneWidget);
  });

  testWidgets('the reserve picker hides the Voleur and cards already spent by the deal', (
    tester,
  ) async {
    final repository = FakeGameRepository(initialGames: [_draftGame(id: 1, playerCount: 8)]);
    await pumpScreen(
      tester,
      const CompositionScreen(gameId: 1),
      overrides: [gameRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Voleur'));
    await tester.pump();
    await tester.tap(find.text('Voyante')); // the only Voyante card is now dealt
    await tester.pump();

    await tester.ensureVisible(find.text('Choisir une carte').first);
    await tester.tap(find.text('Choisir une carte').first);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'Voleur'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Voyante'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Loup-Garou'), findsOneWidget); // 4 in box, 0 dealt
  });

  testWidgets('back chevron discards the draft and returns home', (tester) async {
    final repository = FakeGameRepository();
    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nouvelle partie'));
    await tester.pumpAndSettle();
    expect(repository.allGames, hasLength(1));

    await tester.tap(find.byIcon(AppIcons.back));
    await tester.pumpAndSettle();

    expect(repository.allGames, isEmpty);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  group('the suggestion card', () {
    // The advisor never needs to shuffle within 8-18 players on the base registry (see
    // composition_advisor_test.dart), so this phrase is exactly what 8 players always
    // produces: 2 Loups-Garous + every tier-1/2 special (Cupidon, Voyante, Sorcière,
    // Chasseur) + 2 Villageois filling the rest.
    const suggestionPhrase = '2 Loups-Garous · Cupidon · Voyante · Sorcière · Chasseur · '
        '2 Villageois';

    testWidgets('shows the advisor pick for the current player count', (tester) async {
      final repository = FakeGameRepository(initialGames: [_draftGame(id: 1, playerCount: 8)]);
      await pumpScreen(
        tester,
        const CompositionScreen(gameId: 1),
        overrides: [gameRepositoryProvider.overrideWithValue(repository), _seededAdvisorOverride()],
      );
      await tester.pumpAndSettle();

      expect(find.text('Suggestion pour 8 joueurs'), findsOneWidget);
      expect(find.text(suggestionPhrase), findsOneWidget);
    });

    testWidgets('"Utiliser cette compo" fills the roles and hides the card', (tester) async {
      final repository = FakeGameRepository(initialGames: [_draftGame(id: 1, playerCount: 8)]);
      await pumpScreen(
        tester,
        const CompositionScreen(gameId: 1),
        overrides: [gameRepositoryProvider.overrideWithValue(repository), _seededAdvisorOverride()],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Utiliser cette compo'));
      await tester.pump();

      expect(find.text('8 rôles pour 8 joueurs'), findsOneWidget);
      expect(find.text('Compo complète'), findsOneWidget);
      expect(find.text('Suggestion pour 8 joueurs'), findsNothing);
    });

    testWidgets('reappears once the applied composition is edited again', (tester) async {
      final repository = FakeGameRepository(initialGames: [_draftGame(id: 1, playerCount: 8)]);
      await pumpScreen(
        tester,
        const CompositionScreen(gameId: 1),
        overrides: [gameRepositoryProvider.overrideWithValue(repository), _seededAdvisorOverride()],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Utiliser cette compo'));
      await tester.pump();
      expect(find.text('Suggestion pour 8 joueurs'), findsNothing);

      await tester.ensureVisible(find.text('Petite Fille'));
      await tester.tap(find.text('Petite Fille'));
      await tester.pump();
      expect(find.text('Suggestion pour 8 joueurs'), findsOneWidget);
    });

    testWidgets('follows the player-count stepper', (tester) async {
      final repository = FakeGameRepository(initialGames: [_draftGame(id: 1, playerCount: 8)]);
      await pumpScreen(
        tester,
        const CompositionScreen(gameId: 1),
        overrides: [gameRepositoryProvider.overrideWithValue(repository), _seededAdvisorOverride()],
      );
      await tester.pumpAndSettle();

      await tester.tap(_stepperPlusAt(0));
      await tester.pump();

      expect(find.text('Suggestion pour 9 joueurs'), findsOneWidget);
    });
  });
}
