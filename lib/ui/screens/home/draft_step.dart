import '../../../data/database/app_database.dart';

/// How far an unstarted game got through setup, which decides where Home resumes it.
enum DraftStep {
  /// No composition saved yet.
  composition('composition', 'Composition à faire'),

  /// Composed, but at least one seat has no name yet.
  players('players', 'Joueurs à nommer'),

  /// Composed and every player named: only "Lancer la partie" is left.
  beforeNight('beforeNight', 'Prête à démarrer');

  const DraftStep(this.routeName, this.label);

  /// The go_router route name of the setup screen to resume on.
  final String routeName;

  /// Shown under the draft's title on Home.
  final String label;
}

/// The setup step a draft [game] is at, given its [roster] (empty until a composition is saved).
DraftStep draftStepOf(Game game, List<PlayerRow> roster) {
  if (game.compositionJson == null) return DraftStep.composition;
  final allNamed = roster.isNotEmpty && roster.every((p) => p.name.trim().isNotEmpty);
  return allNamed ? DraftStep.beforeNight : DraftStep.players;
}
