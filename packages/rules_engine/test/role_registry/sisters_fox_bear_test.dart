import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

GameState _table(
  Map<String, String> idToRole, {
  Set<String> dead = const {},
  Map<String, Team> overrides = const {},
  GamePhase phase = GamePhase.night,
}) => GameState.initial(
  players: [
    for (final entry in idToRole.entries)
      Player(
        id: entry.key,
        name: entry.key.toUpperCase(),
        roleId: entry.value,
        alive: !dead.contains(entry.key),
        teamOverride: overrides[entry.key],
      ),
  ],
).copyWith(phase: phase);

void main() {
  final registry = RoleRegistry.all;
  const machine = GameStateMachine();
  const builder = NightScriptBuilder();

  group('the data of the three roles', () {
    test('the Fox is a village role with an optional call that ends when his power does', () {
      final fox = registry.byId('renard');
      expect(fox.team, Team.village);
      expect(fox.hasNightCall, isTrue);
      expect(fox.optionalCall, isTrue);
      expect(fox.wakeCondition, WakeCondition.conditional);
      expect(fox.wakeGuard, WakeGuard.powerUnspent);
    });

    test('the Sisters are a group of two, offered every other night', () {
      final sisters = registry.byId('deux_soeurs');
      expect(sisters.groupSize, 2);
      expect(sisters.multiple, isFalse);
      expect(sisters.optionalCall, isTrue);
      expect(sisters.wakeCondition, WakeCondition.everyOtherNight);
    });

    test('the Bear Tamer is called on the first night only, to be known', () {
      final bear = registry.byId('montreur_d_ours');
      expect(bear.wakeCondition, WakeCondition.firstNightOnly);
      expect(bear.optionalCall, isFalse);
    });

    test('they all sit between the Voyante and the Loups-Garous in the registry', () {
      final ids = registry.roles.map((r) => r.id).toList();
      final voyante = ids.indexOf('voyante');
      final loups = ids.indexOf('loup_garou');
      for (final id in ['renard', 'deux_soeurs', 'montreur_d_ours']) {
        expect(ids.indexOf(id), allOf(greaterThan(voyante), lessThan(loups)), reason: id);
      }
      expect(ids.indexOf('renard'), lessThan(ids.indexOf('deux_soeurs')));
      expect(ids.indexOf('deux_soeurs'), lessThan(ids.indexOf('montreur_d_ours')));
    });
  });

  group('night scripts', () {
    List<String> script(int night, {Set<String> spent = const {}}) => builder
        .build(
          compositionRoles: registry.roles,
          aliveRoleIds: {for (final r in registry.roles) r.id},
          nightIndex: night,
          context: NightContext(nightIndex: night, spentPowers: spent),
        )
        .steps
        .map((s) => s.role.id)
        .toList();

    test('night 1 follows the booklet order', () {
      expect(script(1), [
        'voleur',
        'cupidon',
        'voyante',
        'renard',
        'deux_soeurs',
        'montreur_d_ours',
        'loup_garou',
        'sorciere',
      ]);
    });

    test('night 2 calls the Fox but neither the Sisters nor the Bear Tamer', () {
      expect(script(2), ['voyante', 'renard', 'loup_garou', 'sorciere']);
    });

    test('night 3 offers the Sisters again', () {
      expect(script(3), ['voyante', 'renard', 'deux_soeurs', 'loup_garou', 'sorciere']);
    });

    test('a Fox who lost his power is no longer called', () {
      expect(script(2, spent: {'renard'}), ['voyante', 'loup_garou', 'sorciere']);
    });
  });

  group('FoxSniff', () {
    final table = _table({'a': 'voyante', 'b': 'renard', 'c': 'villageois', 'd': 'loup_garou'});

    test('with a wolf among the three, he keeps his power', () {
      final result = machine.apply(
        state: table,
        action: const FoxSniff(middlePlayerId: 'c', wolfFound: true),
        roleRegistry: registry,
      );
      expect(result.state.spentPowers, isEmpty);
      expect(result.events.single, isA<FoxSniffed>());
    });

    test('with no wolf, his power is gone for good', () {
      final result = machine.apply(
        state: table,
        action: const FoxSniff(middlePlayerId: 'a', wolfFound: false),
        roleRegistry: registry,
      );
      expect(result.state.spentPowers, {'renard': 1});
      expect((result.events.single as FoxSniffed).wolfFound, isFalse);
    });

    test('he cannot sniff again once his power is gone', () {
      final spent = table.copyWith(spentPowers: {'renard': 1});
      expect(
        () => machine.apply(
          state: spent,
          action: const FoxSniff(middlePlayerId: 'a', wolfFound: true),
          roleRegistry: registry,
        ),
        throwsA(isA<InvalidActionError>()),
      );
    });

    test('the middle player must be alive, and it only happens at night', () {
      expect(
        () => machine.apply(
          state: _table({'a': 'voyante', 'b': 'renard'}, dead: {'a'}),
          action: const FoxSniff(middlePlayerId: 'a', wolfFound: true),
          roleRegistry: registry,
        ),
        throwsA(isA<InvalidActionError>()),
      );
      expect(
        () => machine.apply(
          state: _table({'a': 'voyante', 'b': 'renard'}, phase: GamePhase.day),
          action: const FoxSniff(middlePlayerId: 'a', wolfFound: true),
          roleRegistry: registry,
        ),
        throwsA(isA<InvalidActionError>()),
      );
    });

    test('the spent power survives a save', () {
      final spent = table.copyWith(spentPowers: {'renard': 2});
      expect(GameStateJson.decode(GameStateJson.encode(spent)).spentPowers, {'renard': 2});
      expect(
        GameStateJson.decode(GameStateJson.encode(table)).spentPowers,
        isEmpty,
      );
    });
  });

  group('a power lost tonight', () {
    test('only counts from the next night, so tonight\'s script does not move', () {
      final lostTonight = _table({'a': 'voyante'}).copyWith(spentPowers: {'renard': 1});
      expect(lostTonight.spentPowersBeforeTonight, isEmpty);
      expect(lostTonight.copyWith(nightIndex: 2).spentPowersBeforeTonight, {'renard'});
    });
  });

  group('the Fox\'s three', () {
    final table = _table({
      'a': 'villageois',
      'b': 'villageois',
      'c': 'loup_garou',
      'd': 'villageois',
      'e': 'villageois',
    });

    test('are the middle player and the living neighbours either side', () {
      expect(table.foxTrio('b').map((p) => p.id), ['a', 'b', 'c']);
      expect(table.foxTrio('a').map((p) => p.id), ['e', 'a', 'b']);
    });

    test('skip the dead seats', () {
      final gap = _table(
        {'a': 'villageois', 'b': 'villageois', 'c': 'villageois', 'd': 'villageois'},
        dead: {'b'},
      );
      expect(gap.foxTrio('c').map((p) => p.id), ['a', 'c', 'd']);
    });

    test('are fewer when the table is nearly empty', () {
      final small = _table({'a': 'villageois', 'b': 'villageois', 'c': 'villageois'}, dead: {'c'});
      expect(small.foxTrio('a').map((p) => p.id), ['b', 'a']);
    });

    test('hold a wolf when any of them plays with the wolves', () {
      expect(table.wolfAmong(table.foxTrio('b'), registry), isTrue);
      expect(table.wolfAmong(table.foxTrio('e'), registry), isFalse);
    });

    test('hold a wolf when an infected villager is one of them', () {
      final infected = _table(
        {'a': 'villageois', 'b': 'voyante', 'c': 'villageois'},
        overrides: {'a': Team.werewolves},
      );
      expect(infected.wolfAmong(infected.foxTrio('b'), registry), isTrue);
    });
  });

  group('the Bear Tamer growls', () {
    test('when a living neighbour is a wolf', () {
      final state = _table({'a': 'loup_garou', 'b': 'montreur_d_ours', 'c': 'villageois'});
      expect(state.bearGrowls('b', registry), isTrue);
    });

    test('not when both neighbours are villagers, even with a wolf one seat further', () {
      final state = _table({
        'a': 'villageois',
        'b': 'montreur_d_ours',
        'c': 'villageois',
        'd': 'loup_garou',
      });
      expect(state.bearGrowls('b', registry), isFalse);
    });

    test('and a dead neighbour no longer counts: the next living one does', () {
      final state = _table(
        {'a': 'villageois', 'b': 'montreur_d_ours', 'c': 'villageois', 'd': 'loup_garou'},
        dead: {'c'},
      );
      expect(state.bearGrowls('b', registry), isTrue);
    });

    test('every day once he is infected', () {
      final state = _table(
        {'a': 'villageois', 'b': 'montreur_d_ours', 'c': 'villageois'},
        overrides: {'b': Team.werewolves},
      );
      expect(state.bearGrowls('b', registry), isTrue);
    });

    test('never once he is dead', () {
      final state = _table(
        {'a': 'loup_garou', 'b': 'montreur_d_ours', 'c': 'villageois'},
        dead: {'b'},
      );
      expect(state.bearGrowls('b', registry), isFalse);
    });
  });
}
