import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/data/database/app_database.dart';
import 'package:loup_garou_mj/data/models/game_winner.dart';
import 'package:loup_garou_mj/data/models/night_log_entry.dart';
import 'package:loup_garou_mj/data/repositories/drift_game_repository.dart';
import 'package:loup_garou_mj/state/providers/game_repository_provider.dart';
import 'package:loup_garou_mj/state/providers/share_provider.dart';
import 'package:loup_garou_mj/state/session/session_cursor.dart';
import 'package:loup_garou_mj/ui/theme/app_icons.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../support/pump_app.dart';

void main() {
  late AppDatabase db;
  late DriftGameRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftGameRepository(db);
    addTearDown(db.close);
  });

  testWidgets('a completed game opens the recap: winner, counts, survivors only', (tester) async {
    final id = await repo.createGame(initialPlayerCount: 4);
    await repo.saveComposition(
      gameId: id,
      playerCount: 4,
      roleCounts: const {'loup_garou': 1, 'voyante': 1, 'villageois': 2},
    );
    await repo.savePlayerNames(gameId: id, names: const ['Ana', 'Bo', 'Cy', 'Di']);
    await repo.startGame(id);
    final rid = (await repo.getRoster(id)).map((r) => r.id).toList();
    await repo.assignRoles(playerRowIds: [rid[0]], roleId: 'loup_garou');
    await repo.assignRoles(playerRowIds: [rid[1]], roleId: 'voyante');

    final engine = GameState(
      players: [
        Player(id: '${rid[0]}', name: 'Ana', roleId: 'loup_garou'),
        Player(id: '${rid[1]}', name: 'Bo', roleId: 'voyante'),
        Player(
          id: '${rid[2]}',
          name: 'Cy',
          roleId: 'villageois',
          alive: false,
          causeOfDeath: const WolvesKill(),
          diedOnNight: 1,
          diedOnPhase: GamePhase.night,
        ),
        Player(
          id: '${rid[3]}',
          name: 'Di',
          roleId: 'villageois',
          alive: false,
          causeOfDeath: const DayVoteKill(),
          diedOnNight: 2,
          diedOnPhase: GamePhase.day,
        ),
      ],
      nightIndex: 3,
      phase: GamePhase.day,
    );
    await repo.saveSession(
      gameId: id,
      sessionJson: jsonEncode({
        'engine': GameStateJson.encode(engine),
        'cursor': SessionCursor.nightStart.toJson(),
        'day': DaySnapshot.fresh.toJson(),
      }),
    );
    await repo.endGame(gameId: id, winner: GameWinner.wolves);

    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(repo)],
    );
    await tester.pumpAndSettle();

    // the historique row shows the winning side; tapping it opens the recap
    expect(find.text('Loups'), findsOneWidget);
    await tester.tap(find.text('Loups'));
    await tester.pumpAndSettle();

    expect(find.text('Vainqueurs'), findsOneWidget);
    expect(find.text('Les Loups-Garous'), findsOneWidget);
    expect(find.text('2 sur 4'), findsOneWidget); // survivors
    // survivors' roles are shown; the eliminated stay hidden
    expect(find.text('Loup-Garou'), findsOneWidget);
    expect(find.text('Voyante'), findsOneWidget);
    expect(find.textContaining('2 éliminés restent cachés'), findsOneWidget);
  });

  /// A finished 4-player game won by [winner]; [sessionJson], if given, is its saved state.
  Future<int> finishedGame(GameWinner winner, {String? sessionJson}) async {
    final id = await repo.createGame(initialPlayerCount: 4);
    await repo.saveComposition(
      gameId: id,
      playerCount: 4,
      roleCounts: const {'loup_garou': 1, 'villageois': 3},
    );
    await repo.savePlayerNames(gameId: id, names: const ['Ana', 'Bo', 'Cy', 'Di']);
    await repo.startGame(id);
    if (sessionJson != null) await repo.saveSession(gameId: id, sessionJson: sessionJson);
    await repo.endGame(gameId: id, winner: winner);
    return id;
  }

  /// Opens Home and taps the history row labelled [winnerLabel] to show its recap.
  Future<void> openRecap(WidgetTester tester, String winnerLabel) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAppRouter(
      tester,
      overrides: [gameRepositoryProvider.overrideWithValue(repo)],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(winnerLabel));
    await tester.pumpAndSettle();
  }

  testWidgets('the share button hands the journal to the share sheet', (tester) async {
    final id = await finishedGame(GameWinner.village);
    await repo.appendNightLog(
      gameId: id,
      entries: const [
        NightLogEntry(
          phase: JournalPhase.night,
          phaseIndex: 1,
          kind: JournalKind.wolvesTarget,
          args: {'player': 'Cy'},
        ),
      ],
    );
    final shared = <({String text, String subject})>[];
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAppRouter(
      tester,
      overrides: [
        gameRepositoryProvider.overrideWithValue(repo),
        textSharerProvider.overrideWithValue(
          ({required text, required subject}) async => shared.add((text: text, subject: subject)),
        ),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Village'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(AppIcons.share));
    await tester.pumpAndSettle();

    expect(shared, hasLength(1));
    expect(shared.single.text, contains('Vainqueur : Le village'));
    expect(shared.single.text, contains('- Les Loups désignent Cy'));
    expect(shared.single.subject, isNotEmpty);
  });

  testWidgets('the journal screen shares too, and has nothing to share while empty', (tester) async {
    final id = await finishedGame(GameWinner.wolves);
    final shared = <String>[];
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAppRouter(
      tester,
      overrides: [
        gameRepositoryProvider.overrideWithValue(repo),
        textSharerProvider.overrideWithValue(
          ({required text, required subject}) async => shared.add(text),
        ),
      ],
      initialLocation: '/games/$id/journal',
    );
    await tester.pumpAndSettle();

    // an empty journal: the button is inert
    await tester.tap(find.byIcon(AppIcons.share));
    await tester.pumpAndSettle();
    expect(shared, isEmpty);

    await repo.appendNightLog(
      gameId: id,
      entries: const [
        NightLogEntry(
          phase: JournalPhase.night,
          phaseIndex: 1,
          kind: JournalKind.wolvesTarget,
          args: {'player': 'Cy'},
        ),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(AppIcons.share));
    await tester.pumpAndSettle();

    expect(shared.single, contains('- Les Loups désignent Cy'));
  });

  testWidgets('a finished game can be deleted from its recap', (tester) async {
    final id = await finishedGame(GameWinner.village);
    await openRecap(tester, 'Village');

    await tester.tap(find.byIcon(AppIcons.delete));
    await tester.pumpAndSettle();
    expect(find.text('Supprimer cette partie ?'), findsOneWidget);
    await tester.tap(find.text('Supprimer cette partie'));
    await tester.pumpAndSettle();

    expect(await repo.getGame(id), isNull);
    // the recap closed and the history is empty again
    expect(find.text('Vainqueurs'), findsNothing);
    expect(find.text('Aucune partie'), findsOneWidget);
  });

  testWidgets('cancelling the deletion keeps the finished game and its recap', (tester) async {
    final id = await finishedGame(GameWinner.village);
    await openRecap(tester, 'Village');

    await tester.tap(find.byIcon(AppIcons.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(await repo.getGame(id), isNotNull);
    expect(find.text('Vainqueurs'), findsOneWidget);
  });

  testWidgets('a completed game whose saved state is unreadable still opens its recap', (
    tester,
  ) async {
    await finishedGame(GameWinner.wolves, sessionJson: '{not json');
    await openRecap(tester, 'Loups');

    // the winner is stored apart from the damaged blob, so it still shows
    expect(find.text('Vainqueurs'), findsOneWidget);
    expect(find.text('Les Loups-Garous'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
