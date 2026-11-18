import '../../../data/database/app_database.dart';

/// How far an unstarted game got through setup, which decides where Home resumes it.
enum DraftStep {
  /// The composition has not been validated: nothing picked yet, or picked but "Lancer la
  /// partie" never pressed.
  composition('composition', 'Composition à faire'),

  /// Composed (the seats exist), but at least one has no name yet.
  players('players', 'Joueurs à nommer'),

  /// Composed and every player named: only "Lancer la partie" is left.
  beforeNight('beforeNight', 'Prête à démarrer');

  const DraftStep(this.routeName, this.label);

  /// The go_router route name of the setup screen to resume on.
  final String routeName;

  /// Shown under the draft's title on Home.
  final String label;
}

/// The setup step an unstarted game is at, given its [roster].
///
/// The seats are only created when the MJ validates the composition, so an empty roster means the
/// composition is still being edited, whatever was saved of it along the way.
DraftStep draftStepOf(List<PlayerRow> roster) {
  if (roster.isEmpty) return DraftStep.composition;
  final allNamed = roster.every((p) => p.name.trim().isNotEmpty);
  return allNamed ? DraftStep.beforeNight : DraftStep.players;
}
