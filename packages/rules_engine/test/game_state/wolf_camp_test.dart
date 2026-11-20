import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

GameState _table(
  Map<String, String> idToRole, {
  Set<String> dead = const {},
  GamePhase phase = GamePhase.night,
  int night = 1,
}) => GameState.initial(
  players: [
    for (final entry in idToRole.entries)
      Player(
        id: entry.key,
        name: entry.key.toUpperCase(),
        roleId: entry.value,
        alive: !dead.contains(entry.key),
      ),
  ],
).copyWith(phase: phase, nightIndex: night);

void main() {
  const machine = GameStateMachine();
  final registry = RoleRegistry.all;

  ActionResult apply(GameState state, GameAction action) =>
      machine.apply(state: state, action: action, roleRegistry: registry);

  group('the Wild Child', () {
    final table = _table({
      'child': 'enfant_sauvage',
      'model': 'villageois',
      'wolf': 'loup_garou',
      'v': 'villageois',
    });

    GameState withModel() => apply(
      table,
      const WildChildChooseModel(childPlayerId: 'child', modelPlayerId: 'model'),
    ).state;

    test('picks a model, who must be someone else and alive', () {
      expect(withModel().wildChild?.modelId, 'model');
      expect(
        () => apply(
          table,
          const WildChildChooseModel(childPlayerId: 'child', modelPlayerId: 'child'),
        ),
        throwsA(isA<InvalidActionError>()),
      );
      expect(
        () => apply(
          _table({'child': 'enfant_sauvage', 'm': 'villageois'}, dead: {'m'}),
          const WildChildChooseModel(childPlayerId: 'child', modelPlayerId: 'm'),
        ),
        throwsA(isA<InvalidActionError>()),
      );
    });

    test('stays a villager while the model lives', () {
      expect(withModel().playerById('child').teamOverride, isNull);
    });

    test('becomes a werewolf the moment the model dies, however it happens', () {
      for (final cause in [const WolvesKill(), const DayVoteKill()]) {
        final after = withModel().killPlayer('model', cause: cause);
        expect(after.playerById('child').teamOverride, Team.werewolves, reason: '$cause');
      }
    });

    test('does not turn when someone else dies, nor when he is already dead', () {
      expect(
        withModel().killPlayer('v', cause: const WolvesKill()).playerById('child').teamOverride,
        isNull,
      );
      final dead = withModel().killPlayer('child', cause: const WolvesKill());
      expect(dead.killPlayer('model', cause: const WolvesKill()).playerById('child').teamOverride, isNull);
    });

    test('counts with the wolves once turned', () {
      final turned = withModel().killPlayer('model', cause: const WolvesKill());
      expect(turned.aliveWolves(registry), 2);
    });

    test('the pick survives a save', () {
      final back = GameStateJson.decode(GameStateJson.encode(withModel()));
      expect(back.wildChild?.childId, 'child');
      expect(back.wildChild?.modelId, 'model');
    });
  });

  group('the Wolf-Hound', () {
    final table = _table({'dog': 'chien_loup', 'a': 'villageois'});

    test('joins the wolves or the village, and the choice is final', () {
      final wolf = apply(table, const ChienLoupChoose(playerId: 'dog', wolf: true)).state;
      expect(wolf.playerById('dog').teamOverride, Team.werewolves);
      final village = apply(table, const ChienLoupChoose(playerId: 'dog', wolf: false)).state;
      expect(village.playerById('dog').teamOverride, Team.village);

      expect(
        () => apply(wolf, const ChienLoupChoose(playerId: 'dog', wolf: false)),
        throwsA(isA<InvalidActionError>()),
      );
    });
  });

  group('the Cursed Wolf-Father', () {
    final table = _table({'infect': 'infect_pere_des_loups', 'a': 'voyante', 'b': 'villageois'})
        .copyWith(pendingWolfVictimId: 'a');

    test('turns the victim into a wolf instead of killing them, once per game', () {
      final result = apply(table, const InfectVictim());
      final victim = result.state.playerById('a');
      expect(victim.alive, isTrue);
      expect(victim.teamOverride, Team.werewolves);
      expect(victim.hasStatus(PlayerStatus.infected), isTrue);
      expect(victim.roleId, 'voyante'); // keeps the power
      expect(result.state.pendingWolfVictimId, isNull);
      expect(result.state.spentPowers, {'infect_pere_des_loups': 1});
      expect(result.events.single, isA<VictimInfected>());

      // And the night then kills nobody.
      final morning = apply(result.state, const FinalizeNight()).state;
      expect(morning.playerById('a').alive, isTrue);
    });

    test('needs a victim, and cannot be used twice', () {
      expect(
        () => apply(_table({'infect': 'infect_pere_des_loups', 'a': 'voyante'}), const InfectVictim()),
        throwsA(isA<InvalidActionError>()),
      );
      final spent = table.copyWith(spentPowers: {'infect_pere_des_loups': 1});
      expect(() => apply(spent, const InfectVictim()), throwsA(isA<InvalidActionError>()));
    });

    test('an infected player counts as a wolf and wakes with them', () {
      final infected = apply(table, const InfectVictim()).state;
      // the Cursed Wolf-Father himself, and the villager he infected
      expect(infected.aliveWolves(registry), 2);
      expect(infected.wakesWithWolves(infected.playerById('a'), registry), isTrue);
    });

    test('the infection survives a save', () {
      final infected = apply(table, const InfectVictim()).state;
      final back = GameStateJson.decode(GameStateJson.encode(infected));
      expect(back.playerById('a').statuses, {PlayerStatus.infected});
      expect(back.playerById('a').teamOverride, Team.werewolves);
    });
  });

  group('the extra victims of the night', () {
    final table = _table({
      'w': 'loup_garou',
      'big': 'grand_mechant_loup',
      'white': 'loup_garou_blanc',
      'a': 'villageois',
      'b': 'villageois',
      'c': 'villageois',
    });

    test('the Big Bad Wolf eats a second victim, who dies with the first', () {
      var state = apply(table, const WolvesTarget(targetPlayerId: 'a')).state;
      state = apply(state, const BigBadWolfTarget(targetPlayerId: 'b')).state;
      final result = apply(state, const FinalizeNight());

      expect(result.state.playerById('a').alive, isFalse);
      expect(result.state.playerById('b').alive, isFalse);
      expect(result.state.playerById('b').causeOfDeath, isA<WolvesKill>());
      expect(result.state.pendingBigBadWolfVictimId, isNull);
      expect(result.state.playerById('c').alive, isTrue);
    });

    test('the White Werewolf eats a wolf, with a cause of his own', () {
      final state = apply(table, const WhiteWolfEat(targetPlayerId: 'w')).state;
      final result = apply(state, const FinalizeNight());

      expect(result.state.playerById('w').alive, isFalse);
      expect(result.state.playerById('w').causeOfDeath, isA<WhiteWolfKill>());
      expect(result.state.pendingWhiteWolfVictimId, isNull);
    });

    test('the same victim twice dies once', () {
      var state = apply(table, const WolvesTarget(targetPlayerId: 'a')).state;
      state = apply(state, const BigBadWolfTarget(targetPlayerId: 'a')).state;
      final result = apply(state, const FinalizeNight());
      expect(result.events.whereType<PlayerDied>(), hasLength(1));
    });

    test('they are only taken at night, and only alive', () {
      expect(
        () => apply(_table({'a': 'villageois'}, phase: GamePhase.day), const BigBadWolfTarget(targetPlayerId: 'a')),
        throwsA(isA<InvalidActionError>()),
      );
      expect(
        () => apply(_table({'a': 'villageois'}, dead: {'a'}), const WhiteWolfEat(targetPlayerId: 'a')),
        throwsA(isA<InvalidActionError>()),
      );
    });

    test('they survive a save mid-night', () {
      var state = apply(table, const BigBadWolfTarget(targetPlayerId: 'b')).state;
      state = apply(state, const WhiteWolfEat(targetPlayerId: 'w')).state;
      final back = GameStateJson.decode(GameStateJson.encode(state));
      expect(back.pendingBigBadWolfVictimId, 'b');
      expect(back.pendingWhiteWolfVictimId, 'w');
    });

    test('the White Werewolf death cause survives a save', () {
      final dead = table.killPlayer('w', cause: const WhiteWolfKill());
      final back = GameStateJson.decode(GameStateJson.encode(dead));
      expect(back.playerById('w').causeOfDeath, isA<WhiteWolfKill>());
    });
  });

  group('who wakes with the wolves', () {
    final table = _table({
      'w': 'loup_garou',
      'white': 'loup_garou_blanc',
      'v': 'villageois',
    });

    test('the wolves and the White Werewolf, not the villagers', () {
      expect(table.wakesWithWolves(table.playerById('w'), registry), isTrue);
      expect(table.wakesWithWolves(table.playerById('white'), registry), isTrue);
      expect(table.wakesWithWolves(table.playerById('v'), registry), isFalse);
    });
  });

  group('the Big Bad Wolf\'s condition', () {
    test('holds while nobody of the wolf side, no Wild Child and no Wolf-Hound is dead', () {
      final table = _table({'w': 'loup_garou', 'a': 'villageois', 'b': 'villageois'}, dead: {'a'});
      expect(table.wolfSideLost(registry), isFalse);
    });

    test('ends with the death of a wolf, a Wild Child or a Wolf-Hound', () {
      for (final role in ['loup_garou', 'enfant_sauvage', 'chien_loup', 'loup_garou_blanc']) {
        final table = _table({'x': role, 'a': 'villageois'}, dead: {'x'});
        expect(table.wolfSideLost(registry), isTrue, reason: role);
      }
    });
  });

  group('the White Werewolf wins alone', () {
    test('when he is the last one standing', () {
      final table = _table({'white': 'loup_garou_blanc', 'a': 'villageois'}, dead: {'a'});
      expect(proposeVictory(table, registry), VictoryKind.whiteWolf);
    });

  });
}
