import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/data/database/app_database.dart';
import 'package:loup_garou_mj/data/models/game_status.dart';
import 'package:loup_garou_mj/ui/screens/home/draft_step.dart';

Game _game({Map<String, int>? composition}) {
  final now = DateTime(2026, 8, 20);
  return Game(
    id: 1,
    createdAt: now,
    updatedAt: now,
    playerCount: 4,
    compositionJson: composition,
    status: GameStatus.setup,
  );
}

PlayerRow _seat(int index, String name) =>
    PlayerRow(id: index + 1, gameId: 1, seatIndex: index, name: name, alive: true);

void main() {
  const composition = {'loup_garou': 1, 'villageois': 3};

  test('a game with no composition resumes on the composition', () {
    expect(draftStepOf(_game(), const []), DraftStep.composition);
  });

  test('a composed game with unnamed seats resumes on the players', () {
    final roster = [_seat(0, 'Ana'), _seat(1, ''), _seat(2, '  '), _seat(3, 'Di')];

    expect(draftStepOf(_game(composition: composition), roster), DraftStep.players);
  });

  test('a composed game whose roster is not seeded yet resumes on the players', () {
    expect(draftStepOf(_game(composition: composition), const []), DraftStep.players);
  });

  test('a composed game with every player named is ready to start', () {
    final roster = [for (final (i, n) in ['Ana', 'Bo', 'Cy', 'Di'].indexed) _seat(i, n)];

    expect(draftStepOf(_game(composition: composition), roster), DraftStep.beforeNight);
  });

  test('each step names its setup screen route and a label', () {
    expect({for (final s in DraftStep.values) s.routeName}, {
      'composition',
      'players',
      'beforeNight',
    });
    expect(DraftStep.players.label, 'Joueurs à nommer');
  });
}
