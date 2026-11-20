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
  'voleur',
};

const _expectedNoNightCallIds = {'villageois', 'petite_fille', 'chasseur'};
const _expectedNightCallIds = {'voleur', 'cupidon', 'voyante', 'loup_garou', 'sorciere'};

void main() {
  final registry = RoleRegistry.all;

  group('RoleRegistry.all data', () {
    test('has no Capitaine role (an elected status, not a dealt card)', () {
      expect(registry.byIdOrNull('capitaine'), isNull);
    });

    test('has no duplicate ids', () {
      final ids = registry.roles.map((r) => r.id);
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('holds every role of the base game', () {
      expect(registry.roles.map((r) => r.id).toSet(), containsAll(_expectedIds));
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

    test('only the Loups-Garous and the Simples Villageois can have several holders', () {
      for (final id in _expectedIds) {
        final role = registry.byId(id);
        expect(role.multiple, {'loup_garou', 'villageois'}.contains(id), reason: id);
        expect(role.groupSize, 1, reason: id);
      }
    });

    test('among the base roles only the Voleur is ambiguous, and none plays solo', () {
      for (final id in _expectedIds) {
        final role = registry.byId(id);
        expect(role.team == Team.ambiguous, id == 'voleur', reason: id);
        expect(role.team == Team.solo, isFalse, reason: id);
      }
    });

    test('among the base roles only chasseur has a non-none onDeath effect', () {
      for (final role in _expectedIds.map(registry.byId)) {
        final expected = switch (role.id) {
          'chasseur' => DeathEffect.hunterShot,
          _ => DeathEffect.none,
        };
        expect(role.onDeath, expected, reason: role.id);
      }
    });
  });

  group('RoleRegistry lookups', () {
    test('byId returns the expected role', () {
      final voyante = registry.byId('voyante');
      expect(voyante.id, 'voyante');
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
