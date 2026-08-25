import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

void main() {
  group('WakeCondition.isActiveOnNight', () {
    test('everyNight is active on any night', () {
      expect(WakeCondition.everyNight.isActiveOnNight(1), isTrue);
      expect(WakeCondition.everyNight.isActiveOnNight(2), isTrue);
      expect(WakeCondition.everyNight.isActiveOnNight(100), isTrue);
    });

    test('firstNightOnly is active only on night 1', () {
      expect(WakeCondition.firstNightOnly.isActiveOnNight(1), isTrue);
      expect(WakeCondition.firstNightOnly.isActiveOnNight(2), isFalse);
      expect(WakeCondition.firstNightOnly.isActiveOnNight(10), isFalse);
    });

    test('everyOtherNight is not implemented', () {
      expect(
        () => WakeCondition.everyOtherNight.isActiveOnNight(2),
        throwsUnimplementedError,
      );
    });

    test('conditional is not implemented', () {
      expect(
        () => WakeCondition.conditional.isActiveOnNight(1),
        throwsUnimplementedError,
      );
    });
  });
}
