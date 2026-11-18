import '../../../data/database/app_database.dart';
import '../../../l10n/localizations.dart';

/// How far an unstarted game got through setup, which decides where Home resumes it.
enum DraftStep {
  /// The composition has not been validated: nothing picked yet, or picked but "Lancer la
  /// partie" never pressed.
  composition('composition'),

  /// Composed (the seats exist), but at least one has no name yet.
  players('players'),

  /// Composed and every player named: only "Lancer la partie" is left.
  beforeNight('beforeNight');

  const DraftStep(this.routeName);

  /// The go_router route name of the setup screen to resume on.
  final String routeName;
}

/// Shown under the draft's title on Home.
String draftStepLabel(AppLocalizations l10n, DraftStep step) => l10n.draftStepLabel(step.name);

/// The setup step an unstarted game is at, given its [roster].
///
/// The seats are only created when the MJ validates the composition, so an empty roster means the
/// composition is still being edited, whatever was saved of it along the way.
DraftStep draftStepOf(List<PlayerRow> roster) {
  if (roster.isEmpty) return DraftStep.composition;
  final allNamed = roster.every((p) => p.name.trim().isNotEmpty);
  return allNamed ? DraftStep.beforeNight : DraftStep.players;
}
