/// Within a night step: are we learning who holds the role, or running its
/// action? (Night vs day and the night index live on the engine `GameState`,
/// not here.)
enum NightSubStep { identify, act }

/// The app's progress through tonight's derived script. Persisted next to the
/// engine snapshot. Hand-written (not freezed): two fields, and a `fromJson`
/// factory makes freezed pull in json_serializable, which this project doesn't
/// use.
class SessionCursor {
  final int stepIndex;
  final NightSubStep subStep;

  const SessionCursor({required this.stepIndex, required this.subStep});

  /// The start of a fresh night: the first step, learning its holder.
  static const nightStart = SessionCursor(stepIndex: 0, subStep: NightSubStep.identify);

  SessionCursor copyWith({int? stepIndex, NightSubStep? subStep}) => SessionCursor(
    stepIndex: stepIndex ?? this.stepIndex,
    subStep: subStep ?? this.subStep,
  );

  Map<String, dynamic> toJson() => {'stepIndex': stepIndex, 'subStep': subStep.name};

  factory SessionCursor.fromJson(Map<String, dynamic> json) => SessionCursor(
    stepIndex: json['stepIndex'] as int,
    subStep: NightSubStep.values.byName(json['subStep'] as String),
  );

  @override
  bool operator ==(Object other) =>
      other is SessionCursor && other.stepIndex == stepIndex && other.subStep == subStep;

  @override
  int get hashCode => Object.hash(stepIndex, subStep);

  @override
  String toString() => 'SessionCursor($stepIndex, ${subStep.name})';
}

/// Which day-phase screen the MJ is on. Night vs day and the night index come
/// from the engine `GameState`; this only tracks progress *within* a day.
/// `recap` -> `captain` (day 1 only) -> `vote` -> `done` (ready for the next
/// night). Interrupts (a card to reveal, a chain effect, a lover's grief) are
/// driven by engine/session state and shown on top of whatever stage is set.
enum DayStage { recap, captain, vote, done }

/// The app-side day state, persisted next to the engine snapshot and the night
/// cursor. Only meaningful once `engine.phase == GamePhase.day`; reset to
/// [fresh] when the next night starts.
class DaySnapshot {
  final DayStage stage;

  /// The wolves' victim the Witch saved tonight - shown on the J1 recap
  /// ("attaqué puis sauvé"). Set when the life potion is used.
  final String? savedFromWolvesName;

  /// Ids of players the lovers cascade killed that the MJ has not yet
  /// acknowledged (the J4 grief panel). The engine already applied the death;
  /// this only gates the announcement.
  final List<String> loversAck;

  /// Engine ids of dead players the MJ chose not to reveal a card for ("Je ne
  /// note pas"), so the reveal panel stops re-prompting them.
  final List<String> revealSkipped;

  const DaySnapshot({
    this.stage = DayStage.recap,
    this.savedFromWolvesName,
    this.loversAck = const [],
    this.revealSkipped = const [],
  });

  static const fresh = DaySnapshot();

  DaySnapshot copyWith({
    DayStage? stage,
    String? savedFromWolvesName,
    List<String>? loversAck,
    List<String>? revealSkipped,
  }) => DaySnapshot(
    stage: stage ?? this.stage,
    savedFromWolvesName: savedFromWolvesName ?? this.savedFromWolvesName,
    loversAck: loversAck ?? this.loversAck,
    revealSkipped: revealSkipped ?? this.revealSkipped,
  );

  Map<String, dynamic> toJson() => {
    'stage': stage.name,
    if (savedFromWolvesName != null) 'savedFromWolvesName': savedFromWolvesName,
    if (loversAck.isNotEmpty) 'loversAck': loversAck,
    if (revealSkipped.isNotEmpty) 'revealSkipped': revealSkipped,
  };

  factory DaySnapshot.fromJson(Map<String, dynamic> json) => DaySnapshot(
    stage: DayStage.values.byName(json['stage'] as String? ?? 'recap'),
    savedFromWolvesName: json['savedFromWolvesName'] as String?,
    loversAck: (json['loversAck'] as List?)?.cast<String>() ?? const [],
    revealSkipped: (json['revealSkipped'] as List?)?.cast<String>() ?? const [],
  );
}
