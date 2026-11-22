/// The outcome the MJ declares on the end-of-game screen. The app
/// never decides this on its own. [none] is "Partie annulée", not a draw.
///
/// Stored by index in the games table: add new values at the end, never reorder.
enum GameWinner {
  village,
  wolves,
  lovers,
  none,

  /// The Joueur de Flûte has charmed everyone.
  piper,

  /// The Loup-Garou Blanc is the last one alive.
  whiteWolf,

  /// The Ange got himself voted out, or killed, in time.
  angel,

  /// The Abominable Sectaire's group is the only one left.
  sectarian;

  /// The role a game needs for this outcome to be possible, or null for the ones every game
  /// can have. The end-of-game screen only offers a solo winner when its role is in play.
  String? get requiredRoleId => switch (this) {
    piper => 'joueur_de_flute',
    whiteWolf => 'loup_garou_blanc',
    angel => 'ange',
    sectarian => 'abominable_sectaire',
    village || wolves || lovers || none => null,
  };
}
