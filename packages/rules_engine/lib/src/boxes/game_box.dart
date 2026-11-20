/// One physical product the MJ can own: what it holds and how many players it seats. Pure data;
/// [CardPool] turns a set of owned boxes into what can actually be dealt.
class GameBox {
  const GameBox({
    required this.id,
    this.cards = const {},
    this.stickers = const [],
    this.maxPlayers = 0,
  });

  /// Stable key, stored in the owned-boxes setting: never rename one.
  final String id;

  /// Role id -> number of physical cards of that role in the box. Counted in cards, so the
  /// Deux Sœurs are 2 and the Trois Frères 3. Roles the app does not implement yet are listed
  /// anyway and ignored until they are in the registry.
  final Map<String, int> cards;

  /// Roles that ship as a sticker to put on a Simple Villageois card of the base box, not as
  /// a card of their own. Each game, the MJ decides whether that card is a Simple Villageois
  /// or the sticker role.
  final List<String> stickers;

  /// How many players the box alone seats (the booklet's range). 0 for the sticker boxes,
  /// which add no card.
  final int maxPlayers;
}
