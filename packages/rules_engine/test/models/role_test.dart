import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

Role _role(String id, {String name = 'placeholder'}) => Role(
  id: id,
  name: name,
  team: Team.village,
  hasNightCall: false,
  ruleText: 'text',
);

void main() {
  group('Role equality', () {
    test('two roles with the same id are equal, even with different fields', () {
      final a = _role('seer', name: 'Voyante');
      final b = _role('seer', name: 'Something else entirely');
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
