import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/state/composition/composition_draft.dart';
import 'package:loup_garou_mj/state/composition/composition_editor_notifier.dart';
import 'package:loup_garou_mj/state/providers/game_repository_provider.dart';
import 'package:loup_garou_mj/state/settings/settings_providers.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../support/fake_game_repository.dart';

/// A small pool with a two-card group and only three Simples Villageois, so the box limits bite.
CardPool _pool() => CardPool(
  registry: const RoleRegistry([
    Role(id: 'loup_garou', team: Team.werewolves, multiple: true, hasNightCall: false),
    Role(id: 'villageois', team: Team.village, multiple: true, hasNightCall: false),
    Role(id: 'voyante', team: Team.village, hasNightCall: false),
    Role(id: 'deux_soeurs', team: Team.village, groupSize: 2, hasNightCall: false),
  ]),
  boxes: const [
    GameBox(
      id: baseBoxId,
      cards: {'loup_garou': 4, 'villageois': 3, 'voyante': 1, 'deux_soeurs': 2},
    ),
  ],
);

CompositionDraft _draft({int playerCount = 8, Map<String, int> counts = const {}}) =>
    CompositionDraft(gameId: 1, playerCount: playerCount, roleCounts: counts);

void main() {
  group('CompositionDraft against a card pool', () {
    test('cardsLeft counts the deal and the reserve against the pool', () {
      final draft = CompositionDraft(
        gameId: 1,
        playerCount: 8,
        roleCounts: const {'voyante': 1},
        reserveRoleIds: const ['villageois', 'villageois'],
      );
      expect(draft.cardsLeft('voyante', _pool()), 0);
      expect(draft.cardsLeft('villageois', _pool()), 1);
      expect(draft.cardsLeft('villageois', _pool(), ignoreReserveSlot: 0), 2);
    });

    test('a complete deal is valid, even with no card to fill the rest', () {
      expect(_draft(counts: const {'loup_garou': 4, 'villageois': 3, 'voyante': 1}).isValidFor(_pool()), isTrue);
    });

    test('seats left over are fine while enough Simples Villageois remain', () {
      expect(_draft(counts: const {'loup_garou': 4, 'voyante': 1}).isValidFor(_pool()), isTrue);
    });

    test('seats left over are refused when the Simples Villageois cannot fill them', () {
      // 8 players, 1 wolf: 7 seats to fill but only 3 Simples Villageois exist.
      expect(_draft(counts: const {'loup_garou': 1}).isValidFor(_pool()), isFalse);
    });

    test('cards the pool does not hold are refused', () {
      // 5 wolves for 8 players, but the pool has 4 (a box unticked since the draft was made).
      expect(_draft(counts: const {'loup_garou': 5}).isValidFor(_pool()), isFalse);
    });

    test('the Voleur reserve counts against the cards too', () {
      final draft = CompositionDraft(
        gameId: 1,
        playerCount: 8,
        roleCounts: const {'voyante': 1},
        reserveRoleIds: const ['voyante', 'villageois'],
      );
      expect(draft.isValidFor(_pool()), isFalse);
    });

    test('too many roles for the table is still invalid', () {
      expect(_draft(playerCount: 2, counts: const {'loup_garou': 3}).isValidFor(_pool()), isFalse);
    });
  });

  group('CompositionEditor with a card pool', () {
    late FakeGameRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = FakeGameRepository();
      container = ProviderContainer(
        overrides: [
          gameRepositoryProvider.overrideWithValue(repository),
          cardPoolProvider.overrideWithValue(_pool()),
        ],
      );
      addTearDown(container.dispose);
    });

    test('ticking a group role takes all its seats', () async {
      final id = await repository.createGame(initialPlayerCount: 8);
      await container.read(compositionEditorProvider(id).future);
      final notifier = container.read(compositionEditorProvider(id).notifier);

      notifier.toggleRole('deux_soeurs');
      expect(container.read(compositionEditorProvider(id)).value!.roleCounts['deux_soeurs'], 2);

      notifier.toggleRole('deux_soeurs');
      expect(container.read(compositionEditorProvider(id)).value!.roleCounts, isEmpty);
    });

    test('does not launch a deal the pool cannot complete', () async {
      final id = await repository.createGame(initialPlayerCount: 8);
      await container.read(compositionEditorProvider(id).future);
      final notifier = container.read(compositionEditorProvider(id).notifier);
      notifier.setRoleCount('loup_garou', 1);

      await notifier.commit();

      // Still the draft as edited: no Simples Villageois were added to fill the table.
      expect((await repository.getGame(id))?.compositionJson, {'loup_garou': 1});
    });
  });
}
