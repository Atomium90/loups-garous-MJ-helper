import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

const _expectedIds = {
  'loup_garou',
  'villageois',
  'voyante',
  'sorciere',
  'chasseur',
  'petite_fille',
  'cupidon',
  'capitaine',
  'voleur',
};

const _expectedNoNightCallIds = {'villageois', 'petite_fille', 'chasseur', 'capitaine'};
const _expectedNightCallIds = {'voleur', 'cupidon', 'voyante', 'loup_garou', 'sorciere'};

void main() {
  final registry = RoleRegistry.base;

  group('RoleRegistry.base data', () {
    test('has exactly 9 roles', () {
      expect(registry.roles, hasLength(9));
    });

    test('has no duplicate ids', () {
      final ids = registry.roles.map((r) => r.id);
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('ids match exactly the 9 expected base game roles', () {
      expect(registry.roles.map((r) => r.id).toSet(), equals(_expectedIds));
    });

    test('every orderConstraints.roleId resolves to a real role id', () {
      for (final role in registry.roles) {
        for (final constraint in role.orderConstraints) {
          expect(
            registry.byIdOrNull(constraint.roleId),
            isNotNull,
            reason:
                'Role "${role.id}" has a constraint referencing unknown '
                'role id "${constraint.roleId}"',
          );
        }
      }
    });

    test('hasNightCall true iff wakeCondition is set', () {
      for (final role in registry.roles) {
        expect(
          role.wakeCondition != null,
          equals(role.hasNightCall),
          reason: 'Role "${role.id}" has inconsistent hasNightCall/wakeCondition',
        );
      }
    });

    test('non-script roles have hasNightCall false', () {
      for (final id in _expectedNoNightCallIds) {
        expect(registry.byId(id).hasNightCall, isFalse, reason: id);
      }
    });

    test('script roles have hasNightCall true', () {
      for (final id in _expectedNightCallIds) {
        expect(registry.byId(id).hasNightCall, isTrue, reason: id);
      }
    });

    test('voleur and cupidon wake first night only', () {
      expect(registry.byId('voleur').wakeCondition, WakeCondition.firstNightOnly);
      expect(registry.byId('cupidon').wakeCondition, WakeCondition.firstNightOnly);
    });

    test('voyante, loup_garou, sorciere wake every night', () {
      expect(registry.byId('voyante').wakeCondition, WakeCondition.everyNight);
      expect(registry.byId('loup_garou').wakeCondition, WakeCondition.everyNight);
      expect(registry.byId('sorciere').wakeCondition, WakeCondition.everyNight);
    });

    test('cupidon mentions the lovers recognition step', () {
      expect(registry.byId('cupidon').ruleText, contains('amoureux'));
    });
  });

  group('RoleRegistry lookups', () {
    test('byId returns the expected role', () {
      final voyante = registry.byId('voyante');
      expect(voyante.name, 'Voyante');
      expect(voyante.team, Team.village);
    });

    test('byId throws RoleNotFoundException for an unknown id', () {
      expect(() => registry.byId('nonexistent'), throwsA(isA<RoleNotFoundException>()));
    });

    test('byIdOrNull returns null for an unknown id', () {
      expect(registry.byIdOrNull('nonexistent'), isNull);
    });

    test('byTeam(werewolves) returns exactly loup_garou', () {
      expect(registry.byTeam(Team.werewolves).map((r) => r.id), ['loup_garou']);
    });
  });
}
