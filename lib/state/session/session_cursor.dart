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
