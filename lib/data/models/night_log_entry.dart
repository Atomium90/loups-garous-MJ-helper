/// A journal line to append, before it has a `seq` or an id. The state layer
/// renders these from engine events; [GameRepository.appendNightLog] assigns
/// the ordering and persists them as [NightLogRow]s.
class NightLogEntry {
  final String phaseLabel;
  final String iconName;
  final String line;

  const NightLogEntry({
    required this.phaseLabel,
    required this.iconName,
    required this.line,
  });
}
