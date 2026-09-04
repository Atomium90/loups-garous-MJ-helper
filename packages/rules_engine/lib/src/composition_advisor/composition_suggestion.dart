/// A composition proposed by [CompositionAdvisor] for a given player count.
class CompositionSuggestion {
  const CompositionSuggestion(this.roleCounts);

  /// Role id -> count. Sums to the player count the suggestion was made for -
  /// ready to hand straight to `saveComposition`.
  final Map<String, int> roleCounts;
}
