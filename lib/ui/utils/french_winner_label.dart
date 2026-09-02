import 'package:flutter/widgets.dart';

import '../../data/models/game_winner.dart';
import '../theme/app_icons.dart';

/// The winning side, as the MJ declared it on the end-of-game screen.
String frenchWinnerLabel(GameWinner winner) => switch (winner) {
  GameWinner.village => 'Le village',
  GameWinner.wolves => 'Les Loups-Garous',
  GameWinner.lovers => 'Les Amoureux',
  GameWinner.none => 'Personne',
};

IconData frenchWinnerIcon(GameWinner winner) => switch (winner) {
  GameWinner.village => AppIcons.home,
  GameWinner.wolves => AppIcons.wolves,
  GameWinner.lovers => AppIcons.cupid,
  GameWinner.none => AppIcons.cancelled,
};
