import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

void main() {
  final registry = RoleRegistry.all;
  const builder = NightScriptBuilder();

  test('the Trusted Villager is a village role with copies, settled before the night', () {
    final role = registry.byId('villageois_villageois');
    expect(role.team, Team.village);
    expect(role.multiple, isTrue);
    expect(role.preparation, isTrue);
    expect(role.wakeCondition, WakeCondition.firstNightOnly);
  });

  test('it is the first step of the first night, and of no other night', () {
    final roles = [
      for (final r in registry.roles)
        if (const {'villageois_villageois', 'voleur', 'voyante', 'loup_garou'}.contains(r.id)) r,
    ];
    List<String> script(int night) => builder
        .build(
          compositionRoles: roles,
          aliveRoleIds: {for (final r in roles) r.id},
          nightIndex: night,
          context: NightContext(nightIndex: night),
        )
        .steps
        .map((s) => s.role.id)
        .toList();

    expect(script(1), ['villageois_villageois', 'voleur', 'voyante', 'loup_garou']);
    expect(script(2), ['voyante', 'loup_garou']);
  });

  test('the roles settled before the night come first, ahead of every real call', () {
    final before = registry.roles.where((r) => r.preparation).map((r) => r.id).toList();
    expect(before, ['villageois_villageois', 'abominable_sectaire']);
    expect(registry.roles.take(before.length).every((r) => r.preparation), isTrue);
  });
}
