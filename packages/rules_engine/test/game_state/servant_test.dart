import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

/// Ana is the Servante, Bo the villager the village just eliminated with [deadRole].
GameState _table({
  String deadRole = 'voyante',
  String? captain,
  LoversPair? lovers,
  Map<String, Team> overrides = const {},
  Set<PlayerStatus> servantStatuses = const {},
}) => GameState.initial(
  players: [
    Player(
      id: 'ana',
      name: 'Ana',
      roleId: 'servante_devouee',
      teamOverride: overrides['ana'],
      statuses: servantStatuses,
    ),
    Player(id: 'bo', name: 'Bo', roleId: deadRole, alive: false),
    const Player(id: 'cy', name: 'Cy', roleId: 'loup_garou'),
    const Player(id: 'di', name: 'Di', roleId: 'villageois'),
  ],
).copyWith(phase: GamePhase.day, nightIndex: 2, captainPlayerId: captain, lovers: lovers);

void main() {
  const machine = GameStateMachine();
  final registry = RoleRegistry.all;

  ActionResult apply(GameState state, GameAction action) =>
      machine.apply(state: state, action: action, roleRegistry: registry);

  ActionResult take(GameState state) =>
      apply(state, const ServantTakesRole(servantPlayerId: 'ana', deadPlayerId: 'bo'));

  test('the Servante has no call and no side of her own', () {
    final role = registry.byId('servante_devouee');
    expect(role.hasNightCall, isFalse);
    expect(role.team, Team.ambiguous);
  });

  group('taking a role', () {
    test('she becomes the eliminated player\'s role and the day is noted', () {
      final result = take(_table());
      expect(result.state.playerById('ana').roleId, 'voyante');
      expect(result.state.servantTakeover?.roleId, 'voyante');
      expect(result.state.servantTakeover?.day, 2);
      expect(result.events.whereType<ServantTookRole>(), hasLength(1));
    });

    test('only once, in the day, by a living Servante, of an eliminated player', () {
      final done = take(_table()).state;
      expect(() => take(done), throwsA(isA<InvalidActionError>()));
      expect(
        () => take(_table().copyWith(phase: GamePhase.night)),
        throwsA(isA<InvalidActionError>()),
      );
      expect(
        () => apply(
          _table(),
          const ServantTakesRole(servantPlayerId: 'cy', deadPlayerId: 'bo'),
        ),
        throwsA(isA<InvalidActionError>()),
      );
      expect(
        () => apply(
          _table(),
          const ServantTakesRole(servantPlayerId: 'ana', deadPlayerId: 'di'),
        ),
        throwsA(isA<InvalidActionError>()),
      );
    });

    test('a lover cannot use her power, and the dead one\'s love does not come along', () {
      expect(
        () => take(_table(lovers: const LoversPair('ana', 'cy'))),
        throwsA(isA<InvalidActionError>()),
      );
      final state = take(_table(lovers: const LoversPair('bo', 'cy'))).state;
      expect(state.lovers?.partnerOf('ana'), isNull);
    });

    test('her own states stay with her', () {
      final state = take(
        _table(
          overrides: {'ana': Team.werewolves},
          servantStatuses: {PlayerStatus.infected},
        ),
      ).state;
      expect(state.playerById('ana').teamOverride, Team.werewolves);
      expect(state.playerById('ana').hasStatus(PlayerStatus.infected), isTrue);
    });

    test('the dead player\'s states do not come to her', () {
      final dead = _table().playerById('bo').copyWith(
        teamOverride: Team.werewolves,
        statuses: {PlayerStatus.infected, PlayerStatus.charmed},
      );
      final state = take(
        _table().copyWith(
          players: [for (final p in _table().players) if (p.id == 'bo') dead else p],
        ),
      ).state;
      expect(state.playerById('ana').teamOverride, isNull);
      expect(state.playerById('ana').statuses, isEmpty);
    });

    test('the honor of Capitaine is not hers: the dead one\'s is named a successor, hers too', () {
      // The dead Capitaine's succession is the cascade's; she never gets it.
      final fromDead = take(_table(captain: 'bo')).state;
      expect(fromDead.captainPlayerId, 'bo');
      // She was Capitaine herself: she loses it and names a successor right away.
      final herself = take(_table(captain: 'ana')).state;
      expect(herself.cascade?.decision, isA<PendingCaptainSuccession>());
      final after = apply(herself, const CaptainNameSuccessor(successorPlayerId: 'di')).state;
      expect(after.captainPlayerId, 'di');
      expect(after.cascade, isNull);
    });

    test('survives a save', () {
      final state = take(_table()).state;
      final back = GameStateJson.decode(GameStateJson.encode(state));
      expect(back.servantTakeover?.playerId, 'ana');
      expect(back.servantTakeover?.roleId, 'voyante');
      expect(back.servantTakeover?.day, 2);
    });
  });

  group('the new role starts afresh', () {
    test('the Witch gets her two potions back', () {
      final used = _table(deadRole: 'sorciere').copyWith(
        witch: const WitchState(lifePotionUsed: true, deathPotionUsed: true),
      );
      final state = take(used).state;
      expect(state.witch.lifePotionUsed, isFalse);
      expect(state.witch.deathPotionUsed, isFalse);
    });

    test('the Fox and the Wandering Judge get their power back', () {
      final fox = _table(deadRole: 'renard').copyWith(spentPowers: {'renard': 1});
      expect(take(fox).state.spentPowers, isEmpty);
      final judge = _table(deadRole: 'juge_begue').copyWith(spentPowers: {'juge_begue': 1});
      expect(take(judge).state.spentPowers, isEmpty);
    });

    test('the Cursed Wolf-Father\'s power stays spent when the predecessor used it', () {
      final infect = _table(deadRole: 'infect_pere_des_loups').copyWith(
        spentPowers: {'infect_pere_des_loups': 1},
      );
      expect(take(infect).state.spentPowers, {'infect_pere_des_loups': 1});
    });

    test('the Defender may protect the same player as his predecessor', () {
      final defender = _table(deadRole: 'salvateur').copyWith(defenderLastProtectedId: 'di');
      expect(take(defender).state.defenderLastProtectedId, isNull);
    });

    test('the Wild Child picks a new model', () {
      final child = _table(deadRole: 'enfant_sauvage').copyWith(
        wildChild: const WildChildState(childId: 'bo', modelId: 'di'),
      );
      expect(take(child).state.wildChild, isNull);
    });
  });
}
