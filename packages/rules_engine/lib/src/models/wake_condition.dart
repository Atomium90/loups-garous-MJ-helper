enum WakeCondition { everyNight, firstNightOnly, everyOtherNight, conditional }

extension WakeConditionActivation on WakeCondition {
  /// Whether a role with this wake condition is active on [nightIndex]
  /// (1-based).
  bool isActiveOnNight(int nightIndex) {
    switch (this) {
      case WakeCondition.everyNight:
        return true;
      case WakeCondition.firstNightOnly:
        return nightIndex == 1;
      case WakeCondition.everyOtherNight:
      case WakeCondition.conditional:
        // No v1 base-game role uses these. Semantics (which parity, which
        // predicate) are unknown until the first real role needing them is
        // implemented, so fail loud instead of guessing.
        throw UnimplementedError(
          'WakeCondition.$name is not implemented; no v1 role should use it.',
        );
    }
  }
}
