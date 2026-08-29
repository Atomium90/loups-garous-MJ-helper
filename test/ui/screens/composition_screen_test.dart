import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/data/database/app_database.dart';
import 'package:loup_garou_mj/data/models/game_status.dart';
import 'package:loup_garou_mj/state/providers/game_repository_provider.dart';
import 'package:loup_garou_mj/ui/screens/composition/composition_screen.dart';
import 'package:loup_garou_mj/ui/screens/home/home_screen.dart';
import 'package:loup_garou_mj/ui/screens/players/players_screen.dart';
import 'package:loup_garou_mj/ui/theme/app_icons.dart';
import 'package:loup_garou_mj/ui/widgets/app_button.dart';
import 'package:loup_garou_mj/ui/widgets/app_stepper.dart';

import '../../support/fake_game_repository.dart';
import '../../support/pump_app.dart';

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

      expect(find.textContaining('pour 8 joueurs'), findsOneWidget);
      await tester.tap(_stepperMinusAt(0));
      await tester.pump();
      expect(find.textContaining('pour 8 joueurs'), findsOneWidget);

      await tester.tap(_stepperPlusAt(0));
      await tester.pump();
      expect(find.textContaining('pour 9 joueurs'), findsOneWidget);
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
    expect(find.textContaining('pour 18 joueurs'), findsOneWidget);
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
    'Lancer la partie commits the composition (with the villageois top-up) and opens A1',
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
      // Committing the composition doesn't start the game: naming (A1) and the deal (A2) are
      // still setup, and a blank roster gets seeded, sized to the player count.
      expect(saved.status, GameStatus.setup);
      expect(repository.rosterOf(saved.id), hasLength(8));
      // FakeGameRepository.createGame()'s default playerCount is 8; 1 wolf assigned leaves 7
      // remaining, silently topped up as villageois - matches CompositionEditor.commit()'s
      // documented behaviour.
      expect(saved.compositionJson, {'loup_garou': 1, 'villageois': 7});
      // ...and it moves on to A1 "Les joueurs", not back home.
      expect(find.byType(PlayersScreen), findsOneWidget);
      expect(find.text('Les joueurs'), findsOneWidget);
    },
  );

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
}
