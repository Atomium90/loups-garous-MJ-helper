import 'package:rules_engine/rules_engine.dart';

import '../../data/models/game_winner.dart';

/// The outcome the app would propose for [kind]. Only ever a suggestion on screen.
GameWinner winnerFor(VictoryKind kind) => switch (kind) {
  VictoryKind.village => GameWinner.village,
  VictoryKind.werewolves => GameWinner.wolves,
  VictoryKind.lovers => GameWinner.lovers,
  VictoryKind.nobody => GameWinner.none,
};
