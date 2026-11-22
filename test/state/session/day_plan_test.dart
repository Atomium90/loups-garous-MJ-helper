import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/state/session/day_plan.dart';
import 'package:loup_garou_mj/state/session/session_cursor.dart';
import 'package:rules_engine/rules_engine.dart';

GameState _day(int night, {String? captain}) => GameState.initial(
  players: const [
    Player(id: 'a', name: 'A', roleId: 'villageois'),
    Player(id: 'b', name: 'B', roleId: 'villageois'),
  ],
).copyWith(phase: GamePhase.day, nightIndex: night, captainPlayerId: captain);

void main() {
  group('the first day', () {
    test('goes recap, Capitaine, vote, done while there is no Capitaine', () {
      expect(dayStagesFor(_day(1)), [
        DayStage.recap,
        DayStage.captain,
        DayStage.vote,
        DayStage.done,
      ]);
    });

    test('skips the Capitaine election once there is one', () {
      expect(dayStagesFor(_day(1, captain: 'a')), [
        DayStage.recap,
        DayStage.vote,
        DayStage.done,
      ]);
    });
  });

  test('the day before night 1 is only a vote', () {
    final before = _day(1).copyWith(nightIndex: 0);
    expect(dayStagesFor(before), [DayStage.vote, DayStage.done]);
    expect(nextDayStage(DayStage.vote, before), DayStage.done);
  });

  group('with a Bear Tamer', () {
    GameState withBear({bool alive = true}) => GameState.initial(
      players: [
        const Player(id: 'a', name: 'A', roleId: 'villageois'),
        Player(id: 'b', name: 'B', roleId: 'montreur_d_ours', alive: alive),
      ],
    ).copyWith(phase: GamePhase.day, nightIndex: 2);

    test('the morning has a growl right after the recap', () {
      expect(dayStagesFor(withBear()), [
        DayStage.recap,
        DayStage.growl,
        DayStage.vote,
        DayStage.done,
      ]);
      expect(nextDayStage(DayStage.recap, withBear()), DayStage.growl);
      expect(nextDayStage(DayStage.growl, withBear()), DayStage.vote);
    });

    test('the first day goes growl, then the election', () {
      final first = withBear().copyWith(nightIndex: 1);
      expect(dayStagesFor(first), [
        DayStage.recap,
        DayStage.growl,
        DayStage.captain,
        DayStage.vote,
        DayStage.done,
      ]);
    });

    test('the Bear Tamer does not growl once the villagers lost their powers', () {
      expect(dayStagesFor(withBear().copyWith(villagersPowerless: true)), [
        DayStage.recap,
        DayStage.vote,
        DayStage.done,
      ]);
    });

    test('a dead Bear Tamer growls no more', () {
      expect(dayStagesFor(withBear(alive: false)), [
        DayStage.recap,
        DayStage.vote,
        DayStage.done,
      ]);
    });
  });

  test('later days have no election, with a Capitaine or without one', () {
    expect(dayStagesFor(_day(2)), [DayStage.recap, DayStage.vote, DayStage.done]);
    expect(dayStagesFor(_day(3, captain: 'b')), [DayStage.recap, DayStage.vote, DayStage.done]);
  });

  group('nextDayStage', () {
    test('follows the recap with the election on a first day without a Capitaine', () {
      expect(nextDayStage(DayStage.recap, _day(1)), DayStage.captain);
    });

    test('follows the recap with the vote when there is nothing to elect', () {
      expect(nextDayStage(DayStage.recap, _day(2)), DayStage.vote);
      expect(nextDayStage(DayStage.recap, _day(1, captain: 'a')), DayStage.vote);
    });

    test('still moves on when the stage just done is no longer listed for today', () {
      // The Capitaine has just been elected: the game no longer lists the election.
      expect(nextDayStage(DayStage.captain, _day(1, captain: 'a')), DayStage.vote);
    });

    test('follows the vote with done, and stays there', () {
      expect(nextDayStage(DayStage.vote, _day(2)), DayStage.done);
      expect(nextDayStage(DayStage.done, _day(2)), DayStage.done);
    });
  });
}
