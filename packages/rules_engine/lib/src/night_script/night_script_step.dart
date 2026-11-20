import '../models/role.dart';

class NightScriptStep {
  final Role role;

  /// 1-based position within this night's script.
  final int stepIndex;

  const NightScriptStep({required this.role, required this.stepIndex});

  /// The MJ may pass this call without acting.
  bool get optional => role.optionalCall;
}

class NightScript {
  final int nightIndex;
  final List<NightScriptStep> steps;

  const NightScript({required this.nightIndex, required this.steps});
}
