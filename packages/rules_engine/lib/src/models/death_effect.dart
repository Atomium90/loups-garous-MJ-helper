/// A role's on-death effect, resolved by the death cascade before the
/// captain-succession check and any lovers cascade for that same death.
///
/// Captain succession is deliberately not a DeathEffect: being captain is
/// an elected GameState status any role can hold, not a role-intrinsic
/// effect, so it's checked separately against GameState.captainPlayerId.
enum DeathEffect {
  none,

  /// Chasseur: immediately eliminates another living player of their choice.
  hunterShot,
}
