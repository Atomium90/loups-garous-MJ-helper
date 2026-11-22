import 'dart:math';

import '../models/role.dart';
import '../role_registry/role_registry.dart';
import 'game_box.dart';
import 'game_boxes.dart';

/// What can be dealt with the boxes the MJ owns: which roles exist, how many holders each can
/// have, and how many cards are left given a composition in progress. Pure: the registry and
/// the owned boxes go in, the answers come out, so the composition screen, the advisor and the
/// tests all read the same rules.
///
/// Only roles present in [registry] are ever offered: a card of a role the app does not run
/// yet is ignored.
class CardPool {
  /// [boxes] defaults to the real catalogue; a test can pass a small one of its own.
  CardPool({
    required this.registry,
    Iterable<String> ownedBoxIds = const [baseBoxId],
    this.boxes = gameBoxes,
  }) : ownedBoxIds = {
         baseBoxId,
         for (final id in ownedBoxIds)
           if (boxes.any((b) => b.id == id)) id,
       };

  /// Every box that exists, owned or not.
  final List<GameBox> boxes;

  /// Every role the app can resolve, owned or not.
  final RoleRegistry registry;

  /// Always contains [baseBoxId]; unknown ids are dropped.
  final Set<String> ownedBoxIds;

  /// The most players any game seats, whatever the boxes.
  static const absoluteMaxPlayers = 28;
  static const minPlayers = 8;

  static const _simpleVillagerId = 'villageois';

  Iterable<GameBox> get _owned => boxes.where((b) => ownedBoxIds.contains(b.id));

  int _cardsOf(String roleId) => _owned.fold(0, (sum, box) => sum + (box.cards[roleId] ?? 0));

  bool _hasSticker(String roleId) => _owned.any((box) => box.stickers.contains(roleId));

  /// The registry's roles the owned boxes can supply, in registry (wake) order.
  RoleRegistry get available => RoleRegistry([
    for (final role in registry.roles)
      if (isAvailable(role.id)) role,
  ]);

  bool isAvailable(String roleId) =>
      registry.byIdOrNull(roleId) != null && (_cardsOf(roleId) > 0 || _hasSticker(roleId));

  /// A role the owned boxes only supply as a sticker: it takes the place of a Simple Villageois
  /// instead of adding a card.
  bool isStickerOnly(String roleId) =>
      registry.byIdOrNull(roleId) != null && _cardsOf(roleId) == 0 && _hasSticker(roleId);

  /// The most holders of [roleId] one game can have, in slots (a group counts all its members).
  /// Roles without [Role.multiple] stay capped at one holder even when several owned boxes each
  /// ship a card.
  int maxCopies(String roleId) {
    final role = registry.byIdOrNull(roleId);
    if (role == null || !isAvailable(roleId)) return 0;
    if (role.multiple) return _cardsOf(roleId);
    return role.groupSize;
  }

  /// Cards of [roleId] still free for [counts] (role id -> holders already taken, the Voleur's
  /// reserve included). Sticker roles and Simples Villageois share one budget: a sticker role
  /// uses up a Simple Villageois card unless a box owns it as a real card.
  int cardsLeft(String roleId, Map<String, int> counts) {
    if (!isAvailable(roleId)) return 0;
    var left = maxCopies(roleId) - (counts[roleId] ?? 0);
    if (roleId == _simpleVillagerId || isStickerOnly(roleId)) {
      left = min(left, _stickerSlack(counts));
    }
    return max(0, left);
  }

  /// Whether [counts] (role id -> holders, the Voleur's reserve included) can be dealt from the
  /// owned boxes: no role beyond its cards, no role the boxes cannot supply (a box unticked
  /// after the composition was drafted), no more sticker roles than Simples Villageois cards
  /// to put them on.
  bool fits(Map<String, int> counts) {
    for (final entry in counts.entries) {
      if (entry.value > maxCopies(entry.key)) return false;
    }
    return _stickerSlack(counts) >= 0;
  }

  int _stickerSlack(Map<String, int> counts) {
    final stickers = counts.entries
        .where((e) => isStickerOnly(e.key))
        .fold(0, (sum, e) => sum + e.value);
    return _cardsOf(_simpleVillagerId) - (counts[_simpleVillagerId] ?? 0) - stickers;
  }

  /// How many players the owned boxes can seat: the widest booklet range among them, bounded by
  /// the cards that exist.
  int get maxPlayers {
    final cards = registry.roles
        .where((r) => isAvailable(r.id) && !isStickerOnly(r.id))
        .fold(0, (sum, r) => sum + maxCopies(r.id));
    final range = _owned.fold(0, (widest, box) => max(widest, box.maxPlayers));
    return max(minPlayers, min(absoluteMaxPlayers, min(range, cards)));
  }

  /// Distinct roles [boxId] contributes that the app runs (cards and stickers alike).
  int roleCountOf(String boxId) {
    final box = boxes.firstWhere((b) => b.id == boxId, orElse: () => const GameBox(id: ''));
    return {
      ...box.cards.keys,
      ...box.stickers,
    }.where((id) => registry.byIdOrNull(id) != null).length;
  }

  /// Distinct roles the owned boxes make available.
  int get availableRoleCount => registry.roles.where((r) => isAvailable(r.id)).length;
}
