/// Whether two compositions deal the same cards: the same count for every role, and the same
/// Voleur reserve (a missing reserve and an empty one are the same).
///
/// Roles noted on a roster belong to the composition they were noted against, so the repositories
/// forget them when it changes.
bool sameComposition({
  required Map<String, int>? before,
  required List<String>? reserveBefore,
  required Map<String, int> after,
  required List<String> reserveAfter,
}) {
  final old = before ?? const <String, int>{};
  if (old.length != after.length) return false;
  for (final entry in after.entries) {
    if (old[entry.key] != entry.value) return false;
  }
  final oldReserve = [...?reserveBefore]..sort();
  final newReserve = [...reserveAfter]..sort();
  if (oldReserve.length != newReserve.length) return false;
  for (var i = 0; i < oldReserve.length; i++) {
    if (oldReserve[i] != newReserve[i]) return false;
  }
  return true;
}
