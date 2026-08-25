/// A role's on-death effect, resolved by the death cascade before any
/// lovers cascade for that same death.
enum DeathEffect {
  none,

  /// Chasseur: immediately eliminates another living player of their choice.
  hunterShot,

  /// Capitaine: immediately names a successor among the living players.
  captainSuccession,
}
