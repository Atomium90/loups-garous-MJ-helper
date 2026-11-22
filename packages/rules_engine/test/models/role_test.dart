import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

Role _role(String id, {Team team = Team.village, bool multiple = false}) =>
    Role(id: id, team: team, multiple: multiple, hasNightCall: false);

void main() {
  group('Role equality', () {
    test('two roles with the same id are equal, even with different fields', () {
      final a = _role('seer');
      final b = _role('seer', team: Team.werewolves, multiple: true);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('two roles with different ids are not equal', () {
      final a = _role('seer');
      final b = _role('witch');
      expect(a, isNot(equals(b)));
    });
  });
}
