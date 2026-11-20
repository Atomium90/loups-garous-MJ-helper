import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

Role _role(
  WakeCondition condition, {
  int firstWakeNight = 1,
  WakeGuard guard = WakeGuard.none,
  Team team = Team.village,
}) => Role(
  id: 'r',
  team: team,
  hasNightCall: true,
  wakeCondition: condition,
  firstWakeNight: firstWakeNight,
  wakeGuard: guard,
);

bool _active(Role role, int night, {NightContext? context}) => role.wakeCondition!.isActiveFor(
  role,
  context ?? NightContext(nightIndex: night),
);

void main() {
  group('everyNight', () {
    test('is active on any night', () {
      final role = _role(WakeCondition.everyNight);
      expect([1, 2, 100].map((n) => _active(role, n)), everyElement(isTrue));
    });

    test('waits for the night the role starts', () {
      final role = _role(WakeCondition.everyNight, firstWakeNight: 2);
      expect(_active(role, 1), isFalse);
      expect(_active(role, 2), isTrue);
      expect(_active(role, 3), isTrue);
    });
  });

  group('firstNightOnly', () {
    test('is active only on night 1', () {
      final role = _role(WakeCondition.firstNightOnly);
      expect(_active(role, 1), isTrue);
      expect(_active(role, 2), isFalse);
      expect(_active(role, 10), isFalse);
    });

    test('is the night the current holder started, not night 1, when it was handed over', () {
      final role = _role(WakeCondition.firstNightOnly);
      const handedOver = NightContext(nightIndex: 4, firstNightOf: {'r': 4});
      expect(_active(role, 4, context: handedOver), isTrue);
      expect(_active(role, 5, context: const NightContext(nightIndex: 5, firstNightOf: {'r': 4})), isFalse);
      // Before the hand-over night 1 no longer wakes it.
      expect(_active(role, 1, context: const NightContext(nightIndex: 1, firstNightOf: {'r': 4})), isFalse);
    });
  });

  group('everyOtherNight', () {
    test('wakes on nights 1, 3, 5', () {
      final role = _role(WakeCondition.everyOtherNight);
      expect([for (var n = 1; n <= 6; n++) _active(role, n)], [true, false, true, false, true, false]);
    });

    test('counts from the night the role starts', () {
      final role = _role(WakeCondition.everyOtherNight, firstWakeNight: 2);
      expect([for (var n = 1; n <= 6; n++) _active(role, n)], [false, true, false, true, false, true]);
    });
  });

  group('conditional', () {
    test('a one-time power is called until it is spent', () {
      final role = _role(WakeCondition.conditional, guard: WakeGuard.powerUnspent);
      expect(_active(role, 2), isTrue);
      expect(
        _active(role, 3, context: const NightContext(nightIndex: 3, spentPowers: {'r'})),
        isFalse,
      );
      // Someone else's spent power changes nothing.
      expect(
        _active(role, 3, context: const NightContext(nightIndex: 3, spentPowers: {'autre'})),
        isTrue,
      );
    });

    test('a call that ends with the first wolf-side death stops being made', () {
      final role = _role(WakeCondition.conditional, guard: WakeGuard.noWolfDeathYet);
      expect(_active(role, 2), isTrue);
      expect(
        _active(role, 3, context: const NightContext(nightIndex: 3, wolfSideLost: true)),
        isFalse,
      );
    });

    test('a conditional role with no guard is a data error, not a silent default', () {
      final role = _role(WakeCondition.conditional);
      expect(() => _active(role, 1), throwsStateError);
    });
  });

  group('losesNightCall', () {
    test('a village role with no powers left stays asleep', () {
      const powerless = NightContext(nightIndex: 3, villagersPowerless: true);
      expect(losesNightCall(_role(WakeCondition.everyNight), powerless), isTrue);
    });

    test('wolves and solo roles keep theirs', () {
      const powerless = NightContext(nightIndex: 3, villagersPowerless: true);
      expect(losesNightCall(_role(WakeCondition.everyNight, team: Team.werewolves), powerless), isFalse);
      expect(losesNightCall(_role(WakeCondition.everyNight, team: Team.solo), powerless), isFalse);
    });

    test('nobody loses it while the villagers have theirs', () {
      expect(
        losesNightCall(_role(WakeCondition.everyNight), const NightContext(nightIndex: 3)),
        isFalse,
      );
    });
  });
}
