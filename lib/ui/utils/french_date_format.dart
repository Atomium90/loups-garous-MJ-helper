/// A ~12-entry constant list instead of `intl`: the app is French-only, permanently (no
/// localization framework anywhere else in the codebase) - `intl`'s locale-initialization
/// ceremony would be overhead for a single formatting need.
const _frenchMonths = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

/// "Août 2026" - the month-group label above Accueil's Historique rows.
String frenchMonthYearLabel(DateTime date) {
  final month = _frenchMonths[date.month - 1];
  return '${month[0].toUpperCase()}${month.substring(1)} ${date.year}';
}

/// "14 août" - the fallback game name ("Partie du 14 août") when [Game.name] is null.
String frenchDayMonthLabel(DateTime date) => '${date.day} ${_frenchMonths[date.month - 1]}';
