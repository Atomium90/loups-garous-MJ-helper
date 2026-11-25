import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

/// A registry with one of each kind of role the pool tells apart, so the rules are exercised
/// without waiting for the real extension roles to be implemented.
const _registry = RoleRegistry([
  Role(id: 'loup_garou', team: Team.werewolves, multiple: true, hasNightCall: false),
  Role(id: 'villageois', team: Team.village, multiple: true, hasNightCall: false),
  Role(id: 'voyante', team: Team.village, hasNightCall: false),
  Role(id: 'ancien', team: Team.village, hasNightCall: false),
  Role(id: 'salvateur', team: Team.village, hasNightCall: false),
  Role(id: 'deux_soeurs', team: Team.village, groupSize: 2, hasNightCall: false),
  Role(id: 'ange', team: Team.solo, hasNightCall: false),
]);

/// The base box plus [owned]: what most tests mean by "owning" a box.
CardPool _pool([Iterable<String> owned = const []]) =>
    CardPool(registry: _registry, ownedBoxIds: [baseBoxId, ...owned]);

void main() {
  group('owned boxes', () {
    test('unknown ids are dropped, and owning nothing falls back to the base box', () {
      expect(_pool(['nope']).ownedBoxIds, {baseBoxId});
      expect(_pool(['best_of']).ownedBoxIds, {baseBoxId, 'best_of'});
      expect(CardPool(registry: _registry, ownedBoxIds: const []).ownedBoxIds, {baseBoxId});
      expect(CardPool(registry: _registry, ownedBoxIds: const ['nope']).ownedBoxIds, {baseBoxId});
    });

    test('the Best Of alone is enough: the base box is not forced', () {
      final pool = CardPool(registry: _registry, ownedBoxIds: const ['best_of']);
      expect(pool.ownedBoxIds, {'best_of'});
      expect(pool.isAvailable('ange'), isTrue);
      expect(pool.maxCopies('loup_garou'), 3);
      expect(pool.maxCopies('villageois'), 7);
    });
  });

  group('availability', () {
    test('the base box alone offers its own roles only', () {
      final pool = _pool();
      expect(pool.isAvailable('voyante'), isTrue);
      expect(pool.isAvailable('ange'), isFalse);
      expect(pool.isAvailable('ancien'), isFalse);
      expect(pool.available.roles.map((r) => r.id), ['loup_garou', 'villageois', 'voyante']);
    });

    test('a role absent from the registry is never offered, even when a box ships it', () {
      final pool = CardPool(
        registry: const RoleRegistry([
          Role(id: 'loup_garou', team: Team.werewolves, multiple: true, hasNightCall: false),
        ]),
        ownedBoxIds: const ['best_of'],
      );
      expect(pool.isAvailable('ange'), isFalse);
      expect(pool.cardsLeft('ange', const {}), 0);
    });

    test('a sticker role is available with its box, as a sticker-only role', () {
      final pool = _pool(['new_moon']);
      expect(pool.isAvailable('ancien'), isTrue);
      expect(pool.isStickerOnly('ancien'), isTrue);
      expect(pool.isStickerOnly('voyante'), isFalse);
    });

    test('a role that is a real card in an owned box is not sticker-only', () {
      final pool = _pool(['new_moon', 'best_of']);
      expect(pool.isStickerOnly('ancien'), isFalse);
      expect(pool.isStickerOnly('salvateur'), isTrue);
    });
  });

  group('maxCopies', () {
    test('multiple roles sum the cards of every owned box', () {
      expect(_pool().maxCopies('loup_garou'), 4);
      expect(_pool().maxCopies('villageois'), 13);
      expect(_pool(['best_of']).maxCopies('loup_garou'), 7);
      expect(_pool(['best_of']).maxCopies('villageois'), 20);
    });

    test('a unique role stays at one holder even when two boxes ship it', () {
      expect(_pool(['best_of', 'pact']).maxCopies('ancien'), 1);
      expect(_pool(['best_of', 'pact']).maxCopies('voyante'), 1);
    });

    test('a group takes all its slots, however many boxes ship it', () {
      expect(_pool(['best_of']).maxCopies('deux_soeurs'), 2);
      expect(_pool(['best_of', 'pact', 'characters']).maxCopies('deux_soeurs'), 2);
    });

    test('an unavailable role has none', () {
      expect(_pool().maxCopies('ange'), 0);
    });
  });

  group('cardsLeft', () {
    test('subtracts what the composition already holds', () {
      final pool = _pool();
      expect(pool.cardsLeft('loup_garou', const {'loup_garou': 3}), 1);
      expect(pool.cardsLeft('voyante', const {'voyante': 1}), 0);
      expect(pool.cardsLeft('voyante', const {}), 1);
    });

    test('a sticker role consumes a Simple Villageois card', () {
      final pool = _pool(['new_moon']);
      // 13 Simples Villageois in the box: 12 in play + 1 sticker role = 13, no room for more.
      expect(pool.cardsLeft('villageois', const {'villageois': 12}), 1);
      expect(pool.cardsLeft('villageois', const {'villageois': 12, 'ancien': 1}), 0);
      expect(pool.cardsLeft('villageois', const {'villageois': 11, 'ancien': 1}), 1);
    });

    test('a sticker role is refused when every Simple Villageois card is spoken for', () {
      final pool = _pool(['new_moon']);
      expect(pool.cardsLeft('ancien', const {'villageois': 13}), 0);
      expect(pool.cardsLeft('ancien', const {'villageois': 12}), 1);
      expect(pool.cardsLeft('ancien', const {'ancien': 1}), 0);
    });

    test('a role owned as a real card does not use up a Simple Villageois', () {
      final pool = _pool(['new_moon', 'best_of']);
      // Best Of ships its own Elder: it neither takes a sticker nor a villager card.
      expect(pool.cardsLeft('villageois', const {'villageois': 20, 'ancien': 1}), 0);
      expect(pool.cardsLeft('villageois', const {'villageois': 19, 'ancien': 1}), 1);
      // But the Defender is a sticker here: it eats one.
      expect(pool.cardsLeft('villageois', const {'villageois': 19, 'salvateur': 1}), 0);
    });

    test('never negative', () {
      expect(_pool().cardsLeft('voyante', const {'voyante': 3}), 0);
    });
  });

  group('fits', () {
    test('accepts a composition within the cards', () {
      expect(_pool().fits(const {'loup_garou': 4, 'villageois': 13, 'voyante': 1}), isTrue);
      expect(_pool().fits(const {}), isTrue);
    });

    test('refuses more cards than the boxes hold', () {
      expect(_pool().fits(const {'loup_garou': 5}), isFalse);
      expect(_pool(['best_of']).fits(const {'loup_garou': 5}), isTrue);
    });

    test('refuses a role the owned boxes cannot supply', () {
      expect(_pool().fits(const {'ange': 1}), isFalse);
      expect(_pool(['best_of']).fits(const {'ange': 1}), isTrue);
    });

    test('refuses more sticker roles than Simples Villageois cards to put them on', () {
      expect(_pool(['new_moon']).fits(const {'villageois': 12, 'ancien': 1}), isTrue);
      expect(_pool(['new_moon']).fits(const {'villageois': 13, 'ancien': 1}), isFalse);
    });
  });

  group('maxPlayers', () {
    test('is 18 with the base box alone, as the booklet says', () {
      expect(_pool().maxPlayers, 18);
    });

    test('grows with a box that seats more, capped at 28', () {
      expect(_pool(['characters']).maxPlayers, greaterThan(18));
      expect(_pool(['pact', 'best_of', 'characters']).maxPlayers, lessThanOrEqualTo(28));
    });

    test('a sticker box adds no player', () {
      expect(_pool(['new_moon']).maxPlayers, 18);
    });

    test('never drops below the minimum', () {
      final tiny = CardPool(
        registry: const RoleRegistry([
          Role(id: 'loup_garou', team: Team.werewolves, multiple: true, hasNightCall: false),
        ]),
      );
      expect(tiny.maxPlayers, CardPool.minPlayers);
    });
  });

  group('box catalogue', () {
    test('lists the six boxes, the base box first then the Best Of', () {
      expect(gameBoxes.map((b) => b.id), [
        'base',
        'best_of',
        'new_moon',
        'village',
        'characters',
        'pact',
      ]);
    });

    test('roleCountOf counts the roles of a box the app runs', () {
      final pool = _pool();
      expect(pool.roleCountOf('base'), 3);
      expect(pool.roleCountOf('new_moon'), 2);
      expect(pool.roleCountOf('unknown'), 0);
    });

    test('availableRoleCount follows the owned boxes', () {
      expect(_pool().availableRoleCount, 3);
      expect(_pool(['new_moon']).availableRoleCount, 5);
    });
  });
}
