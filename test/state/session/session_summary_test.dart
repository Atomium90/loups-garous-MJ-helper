import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/data/database/app_database.dart';
import 'package:loup_garou_mj/data/models/game_status.dart';
import 'package:loup_garou_mj/data/models/night_log_entry.dart';
import 'package:loup_garou_mj/state/providers/game_repository_provider.dart';
import 'package:loup_garou_mj/state/session/session_cursor.dart';
import 'package:loup_garou_mj/state/session/session_summary_provider.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../support/fake_game_repository.dart';

Game _game({String? sessionJson}) {
  final now = DateTime(2026, 8, 20);
  return Game(
    id: 1,
    createdAt: now,
    updatedAt: now,
    playerCount: 6,
    compositionJson: const {'loup_garou': 2, 'villageois': 4},
    status: GameStatus.inProgress,
    sessionJson: sessionJson,
  );
}

Future<SessionSummary?> _summaryOf(Game game) {
  final container = ProviderContainer(
    overrides: [
      gameRepositoryProvider.overrideWithValue(FakeGameRepository(initialGames: [game])),
    ],
  );
  addTearDown(container.dispose);
  return container.read(sessionSummaryProvider(game.id).future);
}

void main() {
  test('a game that has not started has no summary', () async {
    expect(await _summaryOf(_game()), isNull);
  });

  test('a saved night reads back as its phase and step', () async {
    final engine = GameState.initial(
      players: [
        for (final (i, role) in ['loup_garou', 'loup_garou', 'villageois', 'villageois'].indexed)
          Player(id: '$i', name: 'P$i', roleId: role),
      ],
    );
    final blob = jsonEncode({
      'engine': GameStateJson.encode(engine),
      'cursor': SessionCursor.nightStart.toJson(),
    });

    final summary = await _summaryOf(_game(sessionJson: blob));

    expect(summary!.unreadable, isFalse);
    expect(summary.phase, JournalPhase.night);
    expect(summary.nightIndex, 1);
    expect(summary.step, SummaryStep.role);
    expect(summary.roleId, 'loup_garou');
  });

  group('a saved day reads back as its stage', () {
    final engine = GameState.initial(
      players: [
        for (final (i, role) in ['loup_garou', 'villageois', 'villageois'].indexed)
          Player(id: '$i', name: 'P$i', roleId: role),
      ],
    ).copyWith(phase: GamePhase.day, nightIndex: 2);

    final stages = {
      null: SummaryStep.recap,
      'captain': SummaryStep.captainElection,
      'vote': SummaryStep.villageVote,
      'done': SummaryStep.dayDone,
    };
    for (final MapEntry(key: stage, value: step) in stages.entries) {
      test('stage $stage is $step', () async {
        final blob = jsonEncode({
          'engine': GameStateJson.encode(engine),
          'cursor': SessionCursor.nightStart.toJson(),
          'day': {'stage': ?stage},
        });

        final summary = await _summaryOf(_game(sessionJson: blob));

        expect(summary!.phase, JournalPhase.day);
        expect(summary.nightIndex, 2);
        expect(summary.step, step);
        expect(summary.roleId, isNull);
      });
    }
  });

  group('a saved state that cannot be read', () {
    const blobs = {
      'not JSON at all': '{not json',
      'JSON that is not an object': '[1, 2, 3]',
      'no engine key': '{"cursor": {}}',
      'an engine of the wrong shape': '{"engine": {"phase": "nowhere"}, "cursor": {}}',
    };
    for (final MapEntry(key: label, value: blob) in blobs.entries) {
      test('is reported as unreadable instead of failing: $label', () async {
        final summary = await _summaryOf(_game(sessionJson: blob));

        expect(summary, isNotNull);
        expect(summary!.unreadable, isTrue);
      });
    }
  });
}
