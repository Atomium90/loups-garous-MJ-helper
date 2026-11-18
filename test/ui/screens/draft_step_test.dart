import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/data/database/app_database.dart';
import 'package:loup_garou_mj/ui/screens/home/draft_step.dart';

PlayerRow _seat(int index, String name) =>
    PlayerRow(id: index + 1, gameId: 1, seatIndex: index, name: name, alive: true);

void main() {
  test('a game with no seats yet resumes on the composition', () {
    expect(draftStepOf(const []), DraftStep.composition);
  });

  test('seats with unnamed players resume on the players screen', () {
    final roster = [_seat(0, 'Ana'), _seat(1, ''), _seat(2, '  '), _seat(3, 'Di')];

    expect(draftStepOf(roster), DraftStep.players);
  });

  test('every player named is ready to start', () {
    final roster = [for (final (i, n) in ['Ana', 'Bo', 'Cy', 'Di'].indexed) _seat(i, n)];

    expect(draftStepOf(roster), DraftStep.beforeNight);
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
