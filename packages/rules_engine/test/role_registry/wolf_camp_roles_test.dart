import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

void main() {
  final registry = RoleRegistry.all;
  const builder = NightScriptBuilder();

  group('the data of the five roles', () {
    test('the Wild Child and the Wolf-Hound are ambiguous and called on the first night only', () {
      for (final id in ['enfant_sauvage', 'chien_loup']) {
        final role = registry.byId(id);
        expect(role.team, Team.ambiguous, reason: id);
        expect(role.wakeCondition, WakeCondition.firstNightOnly, reason: id);
      }
    });

    test('the Cursed Wolf-Father and the Big Bad Wolf are wolves with an optional, guarded call', () {
      final infect = registry.byId('infect_pere_des_loups');
      expect(infect.team, Team.werewolves);
      expect(infect.wakeGuard, WakeGuard.powerUnspent);
      expect(infect.optionalCall, isTrue);

      final big = registry.byId('grand_mechant_loup');
      expect(big.team, Team.werewolves);
      expect(big.wakeGuard, WakeGuard.noWolfDeathYet);
      expect(big.optionalCall, isTrue);
    });

    test('the White Werewolf plays alone, from the second night, every other night', () {
      final white = registry.byId('loup_garou_blanc');
      expect(white.team, Team.solo);
      expect(white.wakeCondition, WakeCondition.everyOtherNight);
      expect(white.firstWakeNight, 2);
      expect(white.knownOnFirstNight, isTrue);
    });

    test('the wolf pack sits right after the wolves, in the booklets order', () {
      final ids = registry.roles.map((r) => r.id).toList();
      final wolves = ids.indexOf('loup_garou');
      expect(ids.sublist(wolves, wolves + 4), [
        'loup_garou',
        'loup_garou_blanc',
        'infect_pere_des_loups',
        'grand_mechant_loup',
      ]);
      expect(ids.indexOf('chien_loup'), wolves - 1);
      expect(ids.indexOf('enfant_sauvage'), lessThan(ids.indexOf('montreur_d_ours')));
    });
  });

  group('night scripts', () {
    const ids = {
      'voyante',
      'enfant_sauvage',
      'chien_loup',
      'loup_garou',
      'loup_garou_blanc',
      'infect_pere_des_loups',
      'grand_mechant_loup',
      'sorciere',
    };
    final roles = [for (final r in registry.roles) if (ids.contains(r.id)) r];

    NightScript script(int night, {NightContext? context}) => builder.build(
      compositionRoles: roles,
      aliveRoleIds: ids,
      nightIndex: night,
      context: context ?? NightContext(nightIndex: night),
    );

    List<String> order(NightScript s) => s.steps.map((st) => st.role.id).toList();

    test('night 1 goes through the whole pack in the booklets order', () {
      expect(order(script(1)), [
        'voyante',
        'enfant_sauvage',
        'chien_loup',
        'loup_garou',
        'loup_garou_blanc',
        'infect_pere_des_loups',
        'grand_mechant_loup',
        'sorciere',
      ]);
    });

    test('on night 1 the White Werewolf is only identified', () {
      final steps = {for (final s in script(1).steps) s.role.id: s.identifyOnly};
      expect(steps['loup_garou_blanc'], isTrue);
      expect(steps['loup_garou'], isFalse);
      expect(steps['grand_mechant_loup'], isFalse);
    });

    test('night 2 drops the one-night roles and brings the White Werewolf\'s power', () {
      expect(order(script(2)), [
        'voyante',
        'loup_garou',
        'loup_garou_blanc',
        'infect_pere_des_loups',
        'grand_mechant_loup',
        'sorciere',
      ]);
      expect(script(2).steps.any((s) => s.identifyOnly), isFalse);
    });

    test('the White Werewolf rests on night 3 and is back on night 4', () {
      expect(order(script(3)), isNot(contains('loup_garou_blanc')));
      expect(order(script(4)), contains('loup_garou_blanc'));
    });

    test('the table can ask for his power on the odd nights instead', () {
      final odd = script(
        1,
        context: const NightContext(nightIndex: 1, firstNightOf: {'loup_garou_blanc': 1}),
      );
      final white = odd.steps.firstWhere((s) => s.role.id == 'loup_garou_blanc');
      expect(white.identifyOnly, isFalse);
      expect(order(script(2, context: const NightContext(nightIndex: 2, firstNightOf: {'loup_garou_blanc': 1}))),
          isNot(contains('loup_garou_blanc')));
    });

    test('the Cursed Wolf-Father is not called once he has infected', () {
      expect(
        order(script(3, context: const NightContext(nightIndex: 3, spentPowers: {'infect_pere_des_loups'}))),
        isNot(contains('infect_pere_des_loups')),
      );
    });

    test('the Big Bad Wolf is not called once a wolf, the Wild Child or the Wolf-Hound is dead', () {
      expect(
        order(script(3, context: const NightContext(nightIndex: 3, wolfSideLost: true))),
        isNot(contains('grand_mechant_loup')),
      );
    });
  });

  group('the White Werewolf among the others', () {
    GameState table(Map<String, String> idToRole, {Set<String> dead = const {}}) =>
        GameState.initial(
          players: [
            for (final e in idToRole.entries)
              Player(id: e.key, name: e.key, roleId: e.value, alive: !dead.contains(e.key)),
          ],
        );

    test('wakes with the wolves though he plays alone', () {
      final state = table({'white': 'loup_garou_blanc', 'w': 'loup_garou', 'v': 'villageois'});
      expect(state.wakesWithWolves(state.playerById('white'), registry), isTrue);
      expect(state.playerById('white').sideIn(registry), Team.solo);
    });

    test('does not win while anyone else is alive, wolves or not', () {
      expect(
        proposeVictory(table({'white': 'loup_garou_blanc', 'a': 'villageois'}), registry),
        isNull,
      );
      expect(
        proposeVictory(
          table({'white': 'loup_garou_blanc', 'w': 'loup_garou'}),
          registry,
        ),
        isNull,
      );
    });

    test('the wolves alone do not win with him still alive: he is a solo player', () {
      final state = table({'white': 'loup_garou_blanc', 'w': 'loup_garou', 'v': 'villageois'}, dead: {'v'});
      expect(proposeVictory(state, registry), isNull);
    });

    test('the wolves win once he is dead and only they are left', () {
      final state = table(
        {'white': 'loup_garou_blanc', 'w': 'loup_garou', 'v': 'villageois'},
        dead: {'v', 'white'},
      );
      expect(proposeVictory(state, registry), VictoryKind.werewolves);
    });
  });
}
