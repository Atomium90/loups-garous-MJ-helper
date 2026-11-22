import 'game_box.dart';

/// Id of the base box: always owned, nothing can be played without it.
const baseBoxId = 'base';

/// The cards the base box and the compilations hold alike: one copy of each power card.
const _baseCards = <String, int>{
  'voyante': 1,
  'sorciere': 1,
  'chasseur': 1,
  'cupidon': 1,
  'petite_fille': 1,
  'voleur': 1,
};

/// The New Moon roles, as the one card each is (a real card in the Pact).
const _newMoonCards = <String, int>{
  'salvateur': 1,
  'ancien': 1,
  'bouc_emissaire': 1,
  'joueur_de_flute': 1,
  'idiot_du_village': 1,
};

/// The power cards of the Characters box, which the Pact holds as they are (not the Loups-Garous
/// and the Villageois-Villageois, whose counts differ).
const _charactersCards = <String, int>{
  'ange': 1,
  'juge_begue': 1,
  'chevalier': 1,
  'comedien': 1,
  'servante_devouee': 1,
  'renard': 1,
  'montreur_d_ours': 1,
  'abominable_sectaire': 1,
  'enfant_sauvage': 1,
  'chien_loup': 1,
  'loup_garou_blanc': 1,
  'grand_mechant_loup': 1,
  'infect_pere_des_loups': 1,
  'deux_soeurs': 2,
  'trois_freres': 3,
};

/// The boxes the app knows, in the order the "Mes boîtes" screen lists them. Counts are the
/// current editions' (the booklets): the Pact is a compilation, not the sum of the others
/// (4 Loups-Garous and 9 Simples Villageois in all).
///
/// Left out on purpose: the Capitaine (a title given by vote, not a card of the deal) and the
/// roles that need buildings or event cards, which the app does not run.
const gameBoxes = <GameBox>[
  GameBox(
    id: baseBoxId,
    maxPlayers: 18,
    cards: {'loup_garou': 4, 'villageois': 13, ..._baseCards},
  ),
  GameBox(
    id: 'new_moon',
    stickers: [
      'salvateur',
      'ancien',
      'bouc_emissaire',
      'joueur_de_flute',
      'idiot_du_village',
    ],
  ),
  // Its two roles (Pyromane, Corbeau) need the buildings: nothing playable here yet.
  GameBox(id: 'village'),
  GameBox(
    id: 'characters',
    maxPlayers: 28,
    cards: {'loup_garou': 2, 'villageois_villageois': 2, ..._charactersCards},
  ),
  GameBox(
    id: 'pact',
    maxPlayers: 28,
    cards: {
      'loup_garou': 4,
      'villageois': 9,
      'villageois_villageois': 1,
      ..._baseCards,
      ..._newMoonCards,
      ..._charactersCards,
    },
  ),
  GameBox(
    id: 'best_of',
    maxPlayers: 28,
    cards: {
      'loup_garou': 3,
      'infect_pere_des_loups': 1,
      'grand_mechant_loup': 1,
      'villageois': 7,
      'cupidon': 1,
      'voyante': 1,
      'deux_soeurs': 2,
      'petite_fille': 1,
      'renard': 1,
      'chevalier': 1,
      'ancien': 1,
      'sorciere': 1,
      'montreur_d_ours': 1,
      'chasseur': 1,
      'enfant_sauvage': 1,
      'chien_loup': 1,
      'loup_garou_blanc': 1,
      'joueur_de_flute': 1,
      'ange': 1,
    },
  ),
];

GameBox? gameBoxById(String id) {
  for (final box in gameBoxes) {
    if (box.id == id) return box;
  }
  return null;
}
