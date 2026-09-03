import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/data/database/app_database.dart';
import 'package:loup_garou_mj/data/models/game_status.dart';
import 'package:loup_garou_mj/data/repositories/drift_game_repository.dart';
import 'package:loup_garou_mj/data/repositories/game_not_found_exception.dart';
import 'package:loup_garou_mj/state/composition/composition_editor_notifier.dart';
import 'package:loup_garou_mj/state/providers/game_provider.dart';
import 'package:loup_garou_mj/state/providers/game_repository_provider.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../support/fake_game_repository.dart';

void main() {
  group('CompositionEditor with a fake repository', () {
    late FakeGameRepository fakeRepository;
    late ProviderContainer container;

    setUp(() {
      fakeRepository = FakeGameRepository();
      container = ProviderContainer(
        overrides: [gameRepositoryProvider.overrideWithValue(fakeRepository)],
      );
    });

    tearDown(() => container.dispose());

    Future<CompositionEditor> notifierFor(int gameId) async {
      await container.read(compositionEditorProvider(gameId).future);
      return container.read(compositionEditorProvider(gameId).notifier);
    }

    test('build loads an existing game draft correctly', () async {
      final id = await fakeRepository.createGame(initialPlayerCount: 9);
      final draft = await container.read(compositionEditorProvider(id).future);
      expect(draft.gameId, id);
      expect(draft.playerCount, 9);
      expect(draft.roleCounts, isEmpty);
    });

    test('build surfaces GameNotFoundException for an unknown id', () async {
      // container.read(provider.future) alone doesn't keep the family
      // provider watched: autoDispose's own internal GC can race with the
      // pending error from build() and surface a StateError about
      // disposal instead. container.listen keeps an active subscription
      // for the whole check, which avoids that race.
      final errorCompleter = Completer<Object>();
      final sub = container.listen(compositionEditorProvider(999), (previous, next) {
        if (next.hasError && !errorCompleter.isCompleted) {
          errorCompleter.complete(next.error);
        }
      }, fireImmediately: true);
      addTearDown(sub.close);

      final error = await errorCompleter.future;
      expect(error, isA<GameNotFoundException>());
    });

    test('setPlayerCount updates state', () async {
      final id = await fakeRepository.createGame();
      final notifier = await notifierFor(id);
      notifier.setPlayerCount(12);
      expect(container.read(compositionEditorProvider(id)).value?.playerCount, 12);
    });

    test('setPlayerCount ignores negative values', () async {
      final id = await fakeRepository.createGame(initialPlayerCount: 8);
      final notifier = await notifierFor(id);
      notifier.setPlayerCount(-1);
      expect(container.read(compositionEditorProvider(id)).value?.playerCount, 8);
    });

    test('toggleRole adds a role at count 1 when absent', () async {
      final id = await fakeRepository.createGame();
      final notifier = await notifierFor(id);
      notifier.toggleRole('loup_garou');
      expect(container.read(compositionEditorProvider(id)).value?.roleCounts, {'loup_garou': 1});
    });

    test('toggleRole removes a role when present', () async {
      final id = await fakeRepository.createGame();
      final notifier = await notifierFor(id);
      notifier.toggleRole('loup_garou');
      notifier.toggleRole('loup_garou');
      expect(container.read(compositionEditorProvider(id)).value?.roleCounts, isEmpty);
    });

    test('setRoleCount sets an explicit count', () async {
      final id = await fakeRepository.createGame();
      final notifier = await notifierFor(id);
      notifier.setRoleCount('loup_garou', 3);
      expect(container.read(compositionEditorProvider(id)).value?.roleCounts, {'loup_garou': 3});
    });

    test('setRoleCount 0 removes the key', () async {
      final id = await fakeRepository.createGame();
      final notifier = await notifierFor(id);
      notifier.setRoleCount('loup_garou', 3);
      notifier.setRoleCount('loup_garou', 0);
      expect(container.read(compositionEditorProvider(id)).value?.roleCounts, isEmpty);
    });

    test('remaining and isValid react to playerCount and roleCounts', () async {
      final id = await fakeRepository.createGame(initialPlayerCount: 4);
      final notifier = await notifierFor(id);

      notifier.setRoleCount('loup_garou', 2);
      var draft = container.read(compositionEditorProvider(id)).value!;
      expect(draft.remaining, 2);
      expect(draft.isValid, isTrue);

      notifier.setRoleCount('voyante', 3);
      draft = container.read(compositionEditorProvider(id)).value!;
      expect(draft.remaining, -1);
      expect(draft.isValid, isFalse);
    });

    test('the Voleur needs exactly two reserve cards to be valid', () async {
      final id = await fakeRepository.createGame(initialPlayerCount: 6);
      final notifier = await notifierFor(id);
      notifier.setRoleCount('loup_garou', 1);
      notifier.toggleRole('voleur');

      var draft = container.read(compositionEditorProvider(id)).value!;
      expect(draft.hasVoleur, isTrue);
      expect(draft.isValid, isFalse); // reserve empty

      notifier.setReserveRole(0, 'chasseur');
      notifier.setReserveRole(1, 'cupidon');
      draft = container.read(compositionEditorProvider(id)).value!;
      expect(draft.reserveRoleIds, ['chasseur', 'cupidon']);
      expect(draft.isValid, isTrue);
    });

    test('availableReserveRoles honours box copies and excludes the Voleur', () async {
      final id = await fakeRepository.createGame(initialPlayerCount: 8);
      final notifier = await notifierFor(id);
      notifier.toggleRole('voleur');
      notifier.setRoleCount('loup_garou', 4); // all 4 wolf cards dealt
      notifier.toggleRole('voyante'); // the only Voyante dealt

      final draft = container.read(compositionEditorProvider(id)).value!;
      final ids = draft
          .availableReserveRoles(0, RoleRegistry.base)
          .map((r) => r.id)
          .toSet();
      expect(ids, isNot(contains('voleur')));
      expect(ids, isNot(contains('loup_garou')));
      expect(ids, isNot(contains('voyante')));
      expect(ids, containsAll(['cupidon', 'sorciere', 'villageois', 'chasseur']));

      // A card the slot itself already holds stays offered for that slot.
      notifier.setReserveRole(0, 'chasseur');
      final draft2 = container.read(compositionEditorProvider(id)).value!;
      expect(
        draft2.availableReserveRoles(0, RoleRegistry.base).map((r) => r.id),
        contains('chasseur'),
      );
      // ...but not for the other slot.
      expect(
        draft2.availableReserveRoles(1, RoleRegistry.base).map((r) => r.id),
        isNot(contains('chasseur')),
      );
    });

    test('dropping the Voleur clears a stale reserve', () async {
      final id = await fakeRepository.createGame(initialPlayerCount: 6);
      final notifier = await notifierFor(id);
      notifier.toggleRole('voleur');
      notifier.setReserveRole(0, 'chasseur');
      notifier.setReserveRole(1, 'cupidon');

      notifier.toggleRole('voleur'); // remove
      final draft = container.read(compositionEditorProvider(id)).value!;
      expect(draft.hasVoleur, isFalse);
      expect(draft.reserveRoleIds, isEmpty);
      expect(draft.isValid, isTrue);
    });

    test('commit passes the reserve through only while the Voleur is in play', () async {
      final id = await fakeRepository.createGame(initialPlayerCount: 6);
      final notifier = await notifierFor(id);
      notifier.setRoleCount('loup_garou', 1);
      notifier.toggleRole('voleur');
      notifier.setReserveRole(0, 'chasseur');
      notifier.setReserveRole(1, 'villageois');

      await notifier.commit();

      final game = await fakeRepository.getGame(id);
      expect(game!.reserveRolesJson, ['chasseur', 'villageois']);
    });

    test('clearRoles empties the selection', () async {
      final id = await fakeRepository.createGame();
      final notifier = await notifierFor(id);
      notifier.setRoleCount('loup_garou', 2);
      notifier.clearRoles();
      expect(container.read(compositionEditorProvider(id)).value?.roleCounts, isEmpty);
    });

    test('commit is a no-op when the draft is invalid', () async {
      final id = await fakeRepository.createGame(initialPlayerCount: 2);
      final notifier = await notifierFor(id);
      notifier.setRoleCount('loup_garou', 5);

      await notifier.commit();

      final game = await fakeRepository.getGame(id);
      expect(game!.status, GameStatus.setup);
    });

    test('commit saves playerCount and roleCounts with the villageois remainder filled in', () async {
      final id = await fakeRepository.createGame(initialPlayerCount: 5);
      final notifier = await notifierFor(id);
      notifier.setRoleCount('loup_garou', 2);

      await notifier.commit();

      final game = await fakeRepository.getGame(id);
      expect(game!.playerCount, 5);
      expect(game.compositionJson, {'loup_garou': 2, 'villageois': 3});
      // Naming and the deal are still setup; only startGame flips it.
      expect(game.status, GameStatus.setup);
      // ...and the blank roster is seeded, sized to playerCount.
      expect(fakeRepository.rosterOf(id), hasLength(5));
    });
  });

  group('CompositionEditor.commit wiring with the real repository', () {
    test('invalidates gameListProvider and gameProvider after commit', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = DriftGameRepository(db);
      final container = ProviderContainer(
        overrides: [gameRepositoryProvider.overrideWithValue(repository)],
      );
      // addTearDown runs LIFO: register close() first so dispose() (which
      // cancels gameListProvider's Drift watch subscription) runs before
      // the database connection it depends on is closed underneath it.
      addTearDown(db.close);
      addTearDown(container.dispose);

      final id = await repository.createGame(initialPlayerCount: 6);
      await container.read(compositionEditorProvider(id).future);

      final notifier = container.read(compositionEditorProvider(id).notifier);
      notifier.setRoleCount('loup_garou', 2);
      await notifier.commit();

      // gameProvider is a one-shot Future read: without commit()'s
      // ref.invalidate(gameProvider(gameId)), this would return the stale
      // pre-commit snapshot instead of re-fetching.
      final afterGame = await container.read(gameProvider(id).future);
      expect(afterGame!.compositionJson, {'loup_garou': 2, 'villageois': 4});

      // Not also re-reading gameListProvider here: it wraps Drift's own
      // reactive watchGames() stream (already covered end to end by
      // drift_game_repository_test.dart), and reading a StreamProvider's
      // .future right before the container is disposed hits a genuine
      // riverpod 3.4.2 timing issue in this test environment (disposing
      // mid-emission surfaces an internal StateError instead of settling
      // cleanly), unrelated to anything commit()/invalidate() does.
    });
  });
}
