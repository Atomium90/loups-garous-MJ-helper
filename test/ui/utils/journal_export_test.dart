import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:loup_garou_mj/data/database/app_database.dart';
import 'package:loup_garou_mj/data/models/game_winner.dart';
import 'package:loup_garou_mj/data/models/night_log_entry.dart';
import 'package:loup_garou_mj/data/repositories/drift_game_repository.dart';
import 'package:loup_garou_mj/l10n/localizations.dart';
import 'package:loup_garou_mj/ui/utils/journal_export.dart';

void main() {
  setUpAll(initializeDateFormatting);

  late AppDatabase db;
  late DriftGameRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftGameRepository(db);
    addTearDown(db.close);
  });

  Future<int> game({GameWinner? winner}) async {
    final id = await repo.createGame(initialPlayerCount: 4);
    await repo.saveComposition(
      gameId: id,
      playerCount: 4,
      roleCounts: const {'loup_garou': 1, 'villageois': 3},
    );
    await repo.savePlayerNames(gameId: id, names: const ['Ana', 'Bo', 'Cy', 'Di']);
    await repo.startGame(id);
    await repo.appendNightLog(
      gameId: id,
      entries: const [
        NightLogEntry(
          phase: JournalPhase.night,
          phaseIndex: 1,
          kind: JournalKind.wolvesTarget,
          args: {'player': 'Cy'},
        ),
        NightLogEntry(
          phase: JournalPhase.day,
          phaseIndex: 1,
          kind: JournalKind.villageEliminates,
          args: {'player': 'Di'},
        ),
        NightLogEntry(
          phase: JournalPhase.night,
          phaseIndex: 2,
          kind: JournalKind.wolvesTarget,
          args: {'player': 'Bo'},
        ),
      ],
    );
    if (winner != null) await repo.endGame(gameId: id, winner: winner);
    return id;
  }

  Future<String> text(int id, String locale) async {
    final row = (await repo.getGame(id))!;
    final rows = await repo.watchNightLog(id).first;
    return journalAsText(lookupAppLocalizations(Locale(locale)), row, rows);
  }

  test('lists every line from the first night on, under its phase header', () async {
    final id = await game(winner: GameWinner.wolves);

    final lines = (await text(id, 'fr')).split('\n');

    final night1 = lines.indexOf('NUIT 1');
    final day1 = lines.indexOf('JOUR 1');
    final night2 = lines.indexOf('NUIT 2');
    expect([night1, day1, night2], everyElement(greaterThan(0)));
    expect(night1, lessThan(day1));
    expect(day1, lessThan(night2));
    expect(lines[night1 + 1], '- Les Loups désignent Cy');
    expect(lines[day1 + 1], '- Le village élimine Di');
    expect(lines[night2 + 1], '- Les Loups désignent Bo');
  });

  test('opens with the winner and the deck, in the language of the app', () async {
    final id = await game(winner: GameWinner.wolves);

    expect(await text(id, 'fr'), contains('Vainqueur : Les Loups-Garous'));
    final en = await text(id, 'en');
    expect(en, contains('Winner: The Werewolves'));
    expect(en, contains('NIGHT 1'));
    expect(en, contains('The Werewolves pick Cy'));
  });

  test('a game still being played has no winner line', () async {
    final id = await game();

    expect(await text(id, 'fr'), isNot(contains('Vainqueur')));
  });

  test('a game with no journal is just its header', () async {
    final id = await repo.createGame(initialPlayerCount: 4);
    await repo.startGame(id);

    final lines = (await text(id, 'fr')).split('\n');

    expect(lines, hasLength(2));
  });
}
