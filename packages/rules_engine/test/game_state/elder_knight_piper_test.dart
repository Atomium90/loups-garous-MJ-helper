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

  GameState applyAll(GameState state, List<GameAction> actions) {
    var current = state;
    for (final action in actions) {
      current = apply(current, action).state;
    }
    return current;
  }

  group('the Elder', () {
    final table = _table({'elder': 'ancien', 'w': 'loup_garou', 'v': 'villageois', 'u': 'villageois'});

    test('survives the first time the wolves devour him, without anyone being told', () {
      final state = applyAll(table, [const WolvesTarget(targetPlayerId: 'elder')]);
      final result = apply(state, const FinalizeNight());

      expect(result.state.playerById('elder').alive, isTrue);
      expect(result.state.woundedElders, {'elder'});
      expect(result.events.whereType<PlayerDied>(), isEmpty);
      expect(result.events.whereType<ElderSurvived>(), hasLength(1));
      expect(result.state.villagersPowerless, isFalse);
    });

    test('is eliminated the second time, and the villagers keep their powers', () {
      var state = applyAll(table, [const WolvesTarget(targetPlayerId: 'elder'), const FinalizeNight()]);
      state = applyAll(state, [
        const StartNextNight(),
        const WolvesTarget(targetPlayerId: 'elder'),
        const FinalizeNight(),
      ]);

      expect(state.playerById('elder').alive, isFalse);
      expect(state.playerById('elder').causeOfDeath, isA<WolvesKill>());
      expect(state.villagersPowerless, isFalse);
    });

    test('keeps his life when the Witch heals him: the bite is as if it never happened', () {
      final state = applyAll(table, [
        const WolvesTarget(targetPlayerId: 'elder'),
        const WitchLifePotion(),
        const FinalizeNight(),
      ]);
      expect(state.woundedElders, isEmpty);
      expect(state.playerById('elder').alive, isTrue);
    });

    test('gets back the life of the first bite when the Witch heals him the second time', () {
      final state = applyAll(table.copyWith(woundedElders: {'elder'}), [
        const WolvesTarget(targetPlayerId: 'elder'),
        const WitchLifePotion(),
        const FinalizeNight(),
      ]);
      expect(state.playerById('elder').alive, isTrue);
      expect(state.woundedElders, isEmpty);

      // so the next bites are the first and the second again
      final bitten = applyAll(state.copyWith(phase: GamePhase.night, nightIndex: 3), [
        const WolvesTarget(targetPlayerId: 'elder'),
        const FinalizeNight(),
      ]);
      expect(bitten.playerById('elder').alive, isTrue);
      expect(bitten.woundedElders, {'elder'});
    });

    test('the Big Bad Wolf\'s second victim also gets his first life spared', () {
      final state = applyAll(table, [
        const WolvesTarget(targetPlayerId: 'v'),
        const BigBadWolfTarget(targetPlayerId: 'elder'),
        const FinalizeNight(),
      ]);
      expect(state.playerById('elder').alive, isTrue);
      expect(state.playerById('v').alive, isFalse);
    });

    test('dies at once to the village vote, and the villagers lose their powers', () {
      final day = table.copyWith(phase: GamePhase.day);
      final result = apply(day, const DayVoteElimination(targetPlayerId: 'elder'));
      expect(result.state.playerById('elder').alive, isFalse);
      expect(result.state.villagersPowerless, isTrue);
      expect(result.events.whereType<VillagersLostPowers>(), hasLength(1));
    });

    test('dies at once to the Witch\'s poison, with the same loss', () {
      final state = applyAll(table, [
        const WitchDeathPotion(targetPlayerId: 'elder'),
        const FinalizeNight(),
      ]);
      expect(state.playerById('elder').alive, isFalse);
      expect(state.villagersPowerless, isTrue);
    });

    test('dies at once to the Hunter\'s shot, with the same loss', () {
      final withHunter = _table({
        'hunter': 'chasseur',
        'elder': 'ancien',
        'w': 'loup_garou',
        'v': 'villageois',
      }, phase: GamePhase.day);
      var state = apply(withHunter, const DayVoteElimination(targetPlayerId: 'hunter')).state;
      state = apply(state, const HunterShoot(targetPlayerId: 'elder')).state;
      expect(state.playerById('elder').alive, isFalse);
      expect(state.villagersPowerless, isTrue);
    });

    test('a lover\'s grief takes him without costing the villagers their powers', () {
      final lovers = table.copyWith(lovers: const LoversPair('elder', 'w'), phase: GamePhase.day);
      final state = apply(lovers, const DayVoteElimination(targetPlayerId: 'w')).state;
      expect(state.playerById('elder').alive, isFalse);
      expect(state.villagersPowerless, isFalse);
    });

    test('costs the villagers their powers when his card is only revealed after the vote', () {
      final day = _table({'x': 'villageois', 'w': 'loup_garou', 'v': 'villageois'}, phase: GamePhase.day);
      final voted = apply(day, const DayVoteElimination(targetPlayerId: 'x')).state;
      expect(voted.villagersPowerless, isFalse);

      final revealed = apply(voted, const RevealRole(playerId: 'x', roleId: 'ancien'));
      expect(revealed.state.villagersPowerless, isTrue);
      expect(revealed.events.whereType<VillagersLostPowers>(), hasLength(1));
    });

    test('the first bite of the Cursed Wolf-Father is wasted on him, the second infects', () {
      final bitten = table.copyWith(pendingWolfVictimId: 'elder');
      final first = apply(bitten, const InfectVictim()).state;
      expect(first.playerById('elder').teamOverride, isNull);
      expect(first.woundedElders, {'elder'});
      expect(first.spentPowers.keys, contains('infect_pere_des_loups'));
      expect(first.pendingWolfVictimId, isNull);

      // A second bite (another Father, say): this time it takes.
      final again = first.copyWith(pendingWolfVictimId: 'elder', spentPowers: const {});
      expect(apply(again, const InfectVictim()).state.playerById('elder').teamOverride, Team.werewolves);
    });

    test('a hunter shot is no longer taken once the villagers lost their powers', () {
      final powerless = _table({
        'hunter': 'chasseur',
        'w': 'loup_garou',
        'v': 'villageois',
      }, phase: GamePhase.day).copyWith(villagersPowerless: true);
      final result = apply(powerless, const DayVoteElimination(targetPlayerId: 'hunter'));
      expect(result.state.cascade, isNull);
      expect(result.events.whereType<HunterShotSkipped>(), hasLength(1));
    });

    test('his wounds and the loss survive a save', () {
      final state = table.copyWith(woundedElders: {'elder'}, villagersPowerless: true);
      final back = GameStateJson.decode(GameStateJson.encode(state));
      expect(back.woundedElders, {'elder'});
      expect(back.villagersPowerless, isTrue);
    });
  });

  group('the Knight with the Rusty Sword', () {
    // Seats: the Knight, then a villager, then a wolf, then a villager, then another wolf.
    final table = _table({
      'k': 'chevalier',
      'a': 'villageois',
      'w1': 'loup_garou',
      'b': 'villageois',
      'w2': 'loup_garou',
    });

    GameState devoured({GameState? from}) {
      final state = apply(from ?? table, const WolvesTarget(targetPlayerId: 'k')).state;
      return apply(state, const FinalizeNight()).state;
    }

    test('devoured, he leaves the MJ to say which wolf is diseased', () {
      final after = devoured();
      expect(after.playerById('k').alive, isFalse);
      expect(after.cascade?.decision, isA<PendingKnightWound>());
    });

    test('the wolf chosen is wounded and dies as the next night begins', () {
      var state = devoured();
      state = apply(state, const KnightContaminate(wolfPlayerId: 'w2')).state;
      expect(state.cascade, isNull);
      expect(state.knightWound?.wolfId, 'w2');
      expect(state.knightWound?.dueNight, 2);

      final next = apply(state, const StartNextNight());
      expect(next.state.playerById('w2').alive, isFalse);
      expect(next.state.playerById('w2').causeOfDeath, isA<DiseaseKill>());
      expect(next.state.playerById('w2').diedOnNight, 2);
      expect(next.state.knightWound, isNull);
      expect(next.events.whereType<PlayerDied>().single.cause, isA<DiseaseKill>());
    });

    test('with the setting, the disease strikes at the end of the next night instead', () {
      var state = devoured();
      state = apply(state, const KnightContaminate(wolfPlayerId: 'w2', atNightEnd: true)).state;

      state = apply(state, const StartNextNight()).state;
      expect(state.playerById('w2').alive, isTrue); // still up for the whole night

      state = apply(state, const FinalizeNight()).state;
      expect(state.playerById('w2').alive, isFalse);
      expect(state.playerById('w2').causeOfDeath, isA<DiseaseKill>());
      expect(state.knightWound, isNull);
    });

    test('the MJ can say there is no wolf to wound', () {
      final state = apply(devoured(), const KnightContaminate()).state;
      expect(state.cascade, isNull);
      expect(state.knightWound, isNull);
    });

    test('only a wolf can be wounded', () {
      expect(
        () => apply(devoured(), const KnightContaminate(wolfPlayerId: 'a')),
        throwsA(isA<InvalidActionError>()),
      );
    });

    test('nothing is asked when he dies any other way', () {
      final voted = apply(
        table.copyWith(phase: GamePhase.day),
        const DayVoteElimination(targetPlayerId: 'k'),
      ).state;
      expect(voted.cascade, isNull);

      final poisoned = applyAll(table, [
        const WitchDeathPotion(targetPlayerId: 'k'),
        const FinalizeNight(),
      ]);
      expect(poisoned.cascade, isNull);
    });

    test('nothing is asked once the villagers lost their powers, or when no wolf is left', () {
      expect(devoured(from: table.copyWith(villagersPowerless: true)).cascade, isNull);
      final noWolf = _table({'k': 'chevalier', 'a': 'villageois', 'b': 'villageois'});
      expect(devoured(from: noWolf).cascade, isNull);
    });

    test('a wolf already dead of something else is simply forgotten', () {
      var state = apply(devoured(), const KnightContaminate(wolfPlayerId: 'w2')).state;
      state = state.killPlayer('w2', cause: const DayVoteKill()).copyWith(phase: GamePhase.day);

      final next = apply(state, const StartNextNight());
      expect(next.events.whereType<PlayerDied>(), isEmpty);
      expect(next.state.knightWound, isNull);
    });

    test('the wound survives a save, and the pending question too', () {
      final asked = devoured();
      final backAsked = GameStateJson.decode(GameStateJson.encode(asked));
      expect(backAsked.cascade?.decision, isA<PendingKnightWound>());

      final wounded = apply(asked, const KnightContaminate(wolfPlayerId: 'w2', atNightEnd: true)).state;
      final back = GameStateJson.decode(GameStateJson.encode(wounded));
      expect(back.knightWound?.wolfId, 'w2');
      expect(back.knightWound?.dueNight, 2);
      expect(back.knightWound?.atNightEnd, isTrue);
    });

    test('the disease death cause survives a save', () {
      final dead = table.killPlayer('w1', cause: const DiseaseKill());
      expect(
        GameStateJson.decode(GameStateJson.encode(dead)).playerById('w1').causeOfDeath,
        isA<DiseaseKill>(),
      );
    });
  });

  group('the Piper', () {
    final table = _table({'p': 'joueur_de_flute', 'a': 'villageois', 'b': 'voyante', 'w': 'loup_garou'});

    test('charms two players, who keep their roles', () {
      final result = apply(table, const PiperCharm(playerIds: ['a', 'w']));
      expect(result.state.playerById('a').hasStatus(PlayerStatus.charmed), isTrue);
      expect(result.state.playerById('w').hasStatus(PlayerStatus.charmed), isTrue); // wolves are not immune
      expect(result.state.playerById('a').roleId, 'villageois');
      expect(result.events.single, isA<PlayersCharmed>());
    });

    test('may charm just one when only one is left to charm', () {
      expect(apply(table, const PiperCharm(playerIds: ['a'])).state.playerById('a').hasStatus(PlayerStatus.charmed), isTrue);
    });

    test('cannot charm himself, a charmed player, the dead, nor more than two', () {
      expect(() => apply(table, const PiperCharm(playerIds: ['p'])), throwsA(isA<InvalidActionError>()));
      final charmed = apply(table, const PiperCharm(playerIds: ['a'])).state;
      expect(() => apply(charmed, const PiperCharm(playerIds: ['a'])), throwsA(isA<InvalidActionError>()));
      expect(
        () => apply(_table({'p': 'joueur_de_flute', 'a': 'villageois'}, dead: {'a'}), const PiperCharm(playerIds: ['a'])),
        throwsA(isA<InvalidActionError>()),
      );
      expect(() => apply(table, const PiperCharm(playerIds: ['a', 'b', 'w'])), throwsA(isA<InvalidActionError>()));
      expect(() => apply(table, const PiperCharm(playerIds: [])), throwsA(isA<InvalidActionError>()));
    });

    test('only charms at night', () {
      expect(
        () => apply(table.copyWith(phase: GamePhase.day), const PiperCharm(playerIds: ['a'])),
        throwsA(isA<InvalidActionError>()),
      );
    });

    test('wins the instant every other living player is charmed, even after a vote', () {
      var state = applyAll(table, [
        const PiperCharm(playerIds: ['a', 'b']),
      ]);
      expect(proposeVictory(state, registry), isNull); // the wolf is not charmed yet
      // The next night (through the day), the Piper charms the last one.
      state = applyAll(state.copyWith(phase: GamePhase.day), [const StartNextNight()]);
      state = apply(state, const PiperCharm(playerIds: ['w'])).state;
      expect(proposeVictory(state, registry), VictoryKind.piper);
    });

    test('wins when the last uncharmed player is eliminated by the village', () {
      var state = apply(table, const PiperCharm(playerIds: ['a', 'b'])).state.copyWith(phase: GamePhase.day);
      state = apply(state, const DayVoteElimination(targetPlayerId: 'w')).state;
      expect(proposeVictory(state, registry), VictoryKind.piper);
    });

    test('an infected Piper is a plain wolf and no longer wins by charm', () {
      final infected = table.copyWith(
        players: [
          for (final p in table.players)
            if (p.id == 'p') p.copyWith(teamOverride: Team.werewolves) else p,
        ],
      );
      final state = apply(infected, const PiperCharm(playerIds: ['a', 'b'])).state;
      final all = state.copyWith(
        players: [
          for (final p in state.players)
            if (p.id == 'w') p.copyWith(statuses: {PlayerStatus.charmed}) else p,
        ],
      );
      expect(proposeVictory(all, registry), isNull);
    });

    test('a charmed player stays charmed after a save', () {
      final state = apply(table, const PiperCharm(playerIds: ['a'])).state;
      expect(
        GameStateJson.decode(GameStateJson.encode(state)).playerById('a').statuses,
        {PlayerStatus.charmed},
      );
    });
  });

  group('the roles', () {
    test('the Elder and the Knight are villagers with no night call', () {
      for (final id in ['ancien', 'chevalier']) {
        final role = registry.byId(id);
        expect(role.team, Team.village, reason: id);
        expect(role.hasNightCall, isFalse, reason: id);
      }
      expect(registry.byId('chevalier').onDeath, DeathEffect.knightDisease);
      expect(registry.byId('ancien').onDeath, DeathEffect.none);
    });

    test('the Piper plays alone and is called every night after the Witch', () {
      final piper = registry.byId('joueur_de_flute');
      expect(piper.team, Team.solo);
      expect(piper.wakeCondition, WakeCondition.everyNight);
      final ids = registry.roles.map((r) => r.id).toList();
      expect(ids.indexOf('joueur_de_flute'), ids.indexOf('sorciere') + 1);
    });
  });
}
