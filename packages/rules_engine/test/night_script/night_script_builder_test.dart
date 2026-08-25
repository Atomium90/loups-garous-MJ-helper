import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

Role _scriptRole(
  String id, {
  List<OrderConstraint> orderConstraints = const [],
  WakeCondition wakeCondition = WakeCondition.everyNight,
}) => Role(
  id: id,
  name: id,
  team: Team.village,
  hasNightCall: true,
  wakeCondition: wakeCondition,
  orderConstraints: orderConstraints,
  ruleText: 'text',
);

void main() {
  const builder = NightScriptBuilder();
  final baseRoles = RoleRegistry.base.roles;
  final allBaseIds = baseRoles.map((r) => r.id).toSet();

  group('NightScriptBuilder with real base game data', () {
    test('night 1, everyone alive: full order', () {
      final script = builder.build(
        compositionRoles: baseRoles,
        aliveRoleIds: allBaseIds,
        nightIndex: 1,
      );
      expect(script.steps.map((s) => s.role.id), [
        'voleur',
        'cupidon',
        'voyante',
        'loup_garou',
        'sorciere',
      ]);
    });

    test('night 2, everyone alive: voleur and cupidon excluded', () {
      final script = builder.build(
        compositionRoles: baseRoles,
        aliveRoleIds: allBaseIds,
        nightIndex: 2,
      );
      expect(script.steps.map((s) => s.role.id), [
        'voyante',
        'loup_garou',
        'sorciere',
      ]);
    });

    test('night 5 behaves the same as night 2 (not just night 2 specifically)', () {
      final script = builder.build(
        compositionRoles: baseRoles,
        aliveRoleIds: allBaseIds,
        nightIndex: 5,
      );
      expect(script.steps.map((s) => s.role.id), [
        'voyante',
        'loup_garou',
        'sorciere',
      ]);
    });

    test('a dead voyante is excluded from night 2', () {
      final alive = allBaseIds.difference({'voyante'});
      final script = builder.build(
        compositionRoles: baseRoles,
        aliveRoleIds: alive,
        nightIndex: 2,
      );
      expect(script.steps.map((s) => s.role.id), ['loup_garou', 'sorciere']);
    });

    test('all werewolves dead excludes loup_garou from night 2', () {
      final alive = allBaseIds.difference({'loup_garou'});
      final script = builder.build(
        compositionRoles: baseRoles,
        aliveRoleIds: alive,
        nightIndex: 2,
      );
      expect(script.steps.map((s) => s.role.id), ['voyante', 'sorciere']);
    });

    test('only sorciere alive, night 4: single step, no crash', () {
      final script = builder.build(
        compositionRoles: baseRoles,
        aliveRoleIds: {'sorciere'},
        nightIndex: 4,
      );
      expect(script.steps.map((s) => s.role.id), ['sorciere']);
    });

    test('nobody alive: empty script, no throw', () {
      final script = builder.build(
        compositionRoles: baseRoles,
        aliveRoleIds: {},
        nightIndex: 1,
      );
      expect(script.steps, isEmpty);
    });

    test('a composition without cupidon skips him like a dead role', () {
      final compositionWithoutCupidon = baseRoles
          .where((r) => r.id != 'cupidon')
          .toList();
      final aliveIds = compositionWithoutCupidon.map((r) => r.id).toSet();
      final script = builder.build(
        compositionRoles: compositionWithoutCupidon,
        aliveRoleIds: aliveIds,
        nightIndex: 1,
      );
      expect(script.steps.map((s) => s.role.id), [
        'voleur',
        'voyante',
        'loup_garou',
        'sorciere',
      ]);
    });

    test('determinism: repeated calls with fresh equivalent inputs match', () {
      final first = builder.build(
        compositionRoles: List.of(baseRoles),
        aliveRoleIds: Set.of(allBaseIds),
        nightIndex: 1,
      );
      final second = builder.build(
        compositionRoles: List.of(baseRoles),
        aliveRoleIds: Set.of(allBaseIds),
        nightIndex: 1,
      );
      expect(
        first.steps.map((s) => s.role.id),
        second.steps.map((s) => s.role.id),
      );
    });

    test('determinism does not depend on Set insertion/iteration order', () {
      final orderA = <String>{
        'sorciere',
        'voleur',
        'voyante',
        'cupidon',
        'loup_garou',
      };
      final orderB = <String>{
        'voyante',
        'loup_garou',
        'cupidon',
        'sorciere',
        'voleur',
      };
      final scriptA = builder.build(
        compositionRoles: baseRoles,
        aliveRoleIds: orderA,
        nightIndex: 1,
      );
      final scriptB = builder.build(
        compositionRoles: baseRoles,
        aliveRoleIds: orderB,
        nightIndex: 1,
      );
      expect(
        scriptA.steps.map((s) => s.role.id),
        scriptB.steps.map((s) => s.role.id),
      );
    });
  });

  group('NightScriptBuilder algorithm edge cases (synthetic roles)', () {
    test('a 2-node cycle throws with both role ids', () {
      final a = _scriptRole('a', orderConstraints: [OrderConstraint.after('b')]);
      final b = _scriptRole('b', orderConstraints: [OrderConstraint.after('a')]);
      expect(
        () => builder.build(
          compositionRoles: [a, b],
          aliveRoleIds: {'a', 'b'},
          nightIndex: 1,
        ),
        throwsA(
          isA<NightScriptOrderConflictException>().having(
            (e) => e.involvedRoleIds.toSet(),
            'involvedRoleIds',
            {'a', 'b'},
          ),
        ),
      );
    });

    test('a self-referential constraint throws', () {
      final a = _scriptRole('a', orderConstraints: [OrderConstraint.after('a')]);
      expect(
        () => builder.build(
          compositionRoles: [a],
          aliveRoleIds: {'a'},
          nightIndex: 1,
        ),
        throwsA(isA<NightScriptOrderConflictException>()),
      );
    });

    test('an indirect 3-node cycle throws with all three ids', () {
      final a = _scriptRole('a', orderConstraints: [OrderConstraint.after('c')]);
      final b = _scriptRole('b', orderConstraints: [OrderConstraint.after('a')]);
      final c = _scriptRole('c', orderConstraints: [OrderConstraint.after('b')]);
      expect(
        () => builder.build(
          compositionRoles: [a, b, c],
          aliveRoleIds: {'a', 'b', 'c'},
          nightIndex: 1,
        ),
        throwsA(
          isA<NightScriptOrderConflictException>().having(
            (e) => e.involvedRoleIds.toSet(),
            'involvedRoleIds',
            {'a', 'b', 'c'},
          ),
        ),
      );
    });

    test('a constraint referencing an ineligible-tonight role is ignored, not an error', () {
      final deadRole = _scriptRole('dead_role');
      final x = _scriptRole(
        'x',
        orderConstraints: [OrderConstraint.after('dead_role')],
      );
      final script = builder.build(
        compositionRoles: [deadRole, x],
        aliveRoleIds: {'x'},
        nightIndex: 1,
      );
      expect(script.steps.map((s) => s.role.id), ['x']);
    });

    test('hasNightCall false is always excluded, even if otherwise eligible-looking', () {
      final passive = Role(
        id: 'passive',
        name: 'Passive',
        team: Team.village,
        hasNightCall: false,
        ruleText: 'text',
      );
      final script = builder.build(
        compositionRoles: [passive],
        aliveRoleIds: {'passive'},
        nightIndex: 1,
      );
      expect(script.steps, isEmpty);
    });

    test('an unimplemented wake condition throws', () {
      final weird = _scriptRole(
        'weird',
        wakeCondition: WakeCondition.everyOtherNight,
      );
      expect(
        () => builder.build(
          compositionRoles: [weird],
          aliveRoleIds: {'weird'},
          nightIndex: 1,
        ),
        throwsUnimplementedError,
      );
    });

    test('ties fall back to input order, and flip when input order flips', () {
      final a = _scriptRole('a');
      final b = _scriptRole('b');
      final forward = builder.build(
        compositionRoles: [a, b],
        aliveRoleIds: {'a', 'b'},
        nightIndex: 1,
      );
      final reversed = builder.build(
        compositionRoles: [b, a],
        aliveRoleIds: {'a', 'b'},
        nightIndex: 1,
      );
      expect(forward.steps.map((s) => s.role.id), ['a', 'b']);
      expect(reversed.steps.map((s) => s.role.id), ['b', 'a']);
    });

    test('nightIndex must be >= 1', () {
      expect(
        () => builder.build(compositionRoles: [], aliveRoleIds: {}, nightIndex: 0),
        throwsArgumentError,
      );
      expect(
        () => builder.build(compositionRoles: [], aliveRoleIds: {}, nightIndex: -1),
        throwsArgumentError,
      );
    });

    test('duplicate role ids in compositionRoles throws', () {
      final a1 = _scriptRole('a');
      final a2 = _scriptRole('a');
      expect(
        () => builder.build(
          compositionRoles: [a1, a2],
          aliveRoleIds: {'a'},
          nightIndex: 1,
        ),
        throwsArgumentError,
      );
    });
  });
}
