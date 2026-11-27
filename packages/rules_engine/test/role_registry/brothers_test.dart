import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

void main() {
  final registry = RoleRegistry.all;
  const builder = NightScriptBuilder();

  test('the Brothers are a group of three, woken on the first night only, like the Sisters', () {
    final brothers = registry.byId('trois_freres');
    expect(brothers.team, Team.village);
    expect(brothers.groupSize, 3);
    expect(brothers.multiple, isFalse);
    expect(brothers.optionalCall, isTrue);
    expect(brothers.wakeCondition, WakeCondition.firstNightOnly);
  });

  test('they are called right after the Sisters, before the Wild Child', () {
    final ids = registry.roles.map((r) => r.id).toList();
    expect(ids.indexOf('trois_freres'), ids.indexOf('deux_soeurs') + 1);
    expect(ids.indexOf('trois_freres'), lessThan(ids.indexOf('enfant_sauvage')));
  });

  group('night scripts', () {
    final roles = [
      for (final r in registry.roles)
        if (const {'voyante', 'deux_soeurs', 'trois_freres', 'loup_garou'}.contains(r.id)) r,
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

    test('night 1 wakes both groups so they know each other, and no night after', () {
      expect(script(1), ['voyante', 'deux_soeurs', 'trois_freres', 'loup_garou']);
      expect(script(2), ['voyante', 'loup_garou']);
      expect(script(3), ['voyante', 'loup_garou']);
    });
  });
}
