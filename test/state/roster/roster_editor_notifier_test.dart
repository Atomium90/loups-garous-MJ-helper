import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/data/database/app_database.dart';
import 'package:loup_garou_mj/data/repositories/drift_game_repository.dart';
import 'package:loup_garou_mj/state/providers/game_repository_provider.dart';
import 'package:loup_garou_mj/state/providers/roster_provider.dart';
import 'package:loup_garou_mj/state/roster/roster_editor_notifier.dart';

import '../../support/fake_game_repository.dart';

void main() {
  group('RosterEditor with a fake repository', () {
    late FakeGameRepository fakeRepository;
    late ProviderContainer container;

    setUp(() {
      fakeRepository = FakeGameRepository();
      container = ProviderContainer(
        overrides: [gameRepositoryProvider.overrideWithValue(fakeRepository)],
      );
    });

    tearDown(() => container.dispose());

    /// A game with a seeded blank roster of [size] seats.
    Future<int> gameWithRoster(int size) async {
      final id = await fakeRepository.createGame(initialPlayerCount: size);
      await fakeRepository.saveComposition(gameId: id, playerCount: size, roleCounts: const {});
      return id;
    }

    Future<RosterEditor> notifierFor(int gameId) async {
      await container.read(rosterEditorProvider(gameId).future);
      return container.read(rosterEditorProvider(gameId).notifier);
    }

    test('build seeds the draft from the roster, one blank name per seat', () async {
      final id = await gameWithRoster(4);
      final draft = await container.read(rosterEditorProvider(id).future);
      expect(draft.gameId, id);
      expect(draft.names, ['', '', '', '']);
      expect(draft.total, 4);
      expect(draft.namedCount, 0);
      expect(draft.allNamed, isFalse);
    });

    test('setName updates one seat and the derived counts', () async {
      final id = await gameWithRoster(3);
      final notifier = await notifierFor(id);

      notifier.setName(0, 'Camille');
      notifier.setName(1, 'Julien');
      var draft = container.read(rosterEditorProvider(id)).value!;
      expect(draft.names, ['Camille', 'Julien', '']);
      expect(draft.namedCount, 2);
      expect(draft.allNamed, isFalse);

      notifier.setName(2, 'Noa');
      draft = container.read(rosterEditorProvider(id)).value!;
      expect(draft.allNamed, isTrue);
    });

    test('a whitespace-only name does not count as named', () async {
      final id = await gameWithRoster(1);
      final notifier = await notifierFor(id);
      notifier.setName(0, '   ');
      expect(container.read(rosterEditorProvider(id)).value!.allNamed, isFalse);
    });

    test('setName ignores an out-of-range seat index', () async {
      final id = await gameWithRoster(2);
      final notifier = await notifierFor(id);
      notifier.setName(5, 'Nope');
      expect(container.read(rosterEditorProvider(id)).value!.names, ['', '']);
    });

    test('commit is a no-op until every seat is named', () async {
      final id = await gameWithRoster(2);
      final notifier = await notifierFor(id);
      notifier.setName(0, 'Lina');

      await notifier.commit();

      expect(fakeRepository.rosterOf(id).map((p) => p.name), ['', '']);
    });

    test('commit persists trimmed names once the roster is complete', () async {
      final id = await gameWithRoster(2);
      final notifier = await notifierFor(id);
      notifier.setName(0, '  Lina  ');
      notifier.setName(1, 'Théo');

      await notifier.commit();

      expect(fakeRepository.rosterOf(id).map((p) => p.name), ['Lina', 'Théo']);
    });
  });

  group('RosterEditor.commit wiring with the real repository', () {
    test('invalidates rosterProvider so a re-read sees the persisted names', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = DriftGameRepository(db);
      final container = ProviderContainer(
        overrides: [gameRepositoryProvider.overrideWithValue(repository)],
      );
      // addTearDown runs LIFO: close() first so dispose() (cancelling
      // rosterProvider's Drift watch) runs before the DB connection closes.
      addTearDown(db.close);
      addTearDown(container.dispose);

      final id = await repository.createGame(initialPlayerCount: 2);
      await repository.saveComposition(gameId: id, playerCount: 2, roleCounts: const {});
      await container.read(rosterEditorProvider(id).future);

      final notifier = container.read(rosterEditorProvider(id).notifier);
      notifier.setName(0, 'Camille');
      notifier.setName(1, 'Julien');
      await notifier.commit();

      final rows = await container.read(rosterProvider(id).future);
      expect(rows.map((p) => p.name), ['Camille', 'Julien']);
    });
  });
}
