import 'package:collection/collection.dart';

import '../models/order_constraint.dart';
import '../models/role.dart';
import '../models/wake_condition.dart';
import 'night_script_step.dart';

/// Turns a game composition, who's currently alive, and the current night
/// into the ordered sequence of night-call steps the MJ follows.
///
/// Decoupled from any Player/Game model on purpose: callers derive
/// [aliveRoleIds] from their own player list (or pass every composition
/// role id, to preview night 1 before a game exists).
class NightScriptBuilder {
  const NightScriptBuilder();

  NightScript build({
    required List<Role> compositionRoles,
    required Set<String> aliveRoleIds,
    required int nightIndex,
  }) {
    if (nightIndex < 1) {
      throw ArgumentError.value(nightIndex, 'nightIndex', 'must be >= 1');
    }

    final compositionIds = compositionRoles.map((r) => r.id).toList();
    if (compositionIds.toSet().length != compositionIds.length) {
      throw ArgumentError.value(
        compositionRoles,
        'compositionRoles',
        'contains duplicate role ids',
      );
    }

    final eligible = compositionRoles.where((role) {
      if (!role.hasNightCall) return false;
      if (!aliveRoleIds.contains(role.id)) return false;
      final wakeCondition = role.wakeCondition;
      if (wakeCondition == null) {
        throw StateError(
          'Role "${role.id}" has hasNightCall=true but no wakeCondition set',
        );
      }
      return wakeCondition.isActiveOnNight(nightIndex);
    }).toList();

    final ordered = _topoSort(eligible);

    return NightScript(
      nightIndex: nightIndex,
      steps: [
        for (var i = 0; i < ordered.length; i++)
          NightScriptStep(role: ordered[i], stepIndex: i + 1),
      ],
    );
  }

  /// Kahn's algorithm. Deterministic tie-break: at each step, the first
  /// role (in [eligible]'s original order) with in-degree 0 is picked, so
  /// declaration order in the composition/registry is the tie-break, no
  /// separate priority field needed.
  List<Role> _topoSort(List<Role> eligible) {
    final byId = {for (final r in eligible) r.id: r};
    final indegree = {for (final r in eligible) r.id: 0};
    final successors = {for (final r in eligible) r.id: <String>{}};

    for (final role in eligible) {
      for (final constraint in role.orderConstraints) {
        if (!byId.containsKey(constraint.roleId)) {
          // Not eligible tonight (dead, off-night, or not in this
          // composition): ignore, this is expected and not an error.
          continue;
        }
        final String predecessorId;
        final String successorId;
        switch (constraint.relation) {
          case OrderRelation.after:
            predecessorId = constraint.roleId;
            successorId = role.id;
          case OrderRelation.before:
            predecessorId = role.id;
            successorId = constraint.roleId;
        }
        if (successors[predecessorId]!.add(successorId)) {
          indegree[successorId] = indegree[successorId]! + 1;
        }
      }
    }

    final result = <Role>[];
    final remaining = List<Role>.from(eligible);
    while (remaining.isNotEmpty) {
      final next = remaining.firstWhereOrNull((r) => indegree[r.id] == 0);
      if (next == null) {
        throw NightScriptOrderConflictException(
          remaining.map((r) => r.id).toList(),
        );
      }
      result.add(next);
      remaining.remove(next);
      for (final successorId in successors[next.id]!) {
        indegree[successorId] = indegree[successorId]! - 1;
      }
    }
    return result;
  }
}

/// Thrown when [orderConstraints] among tonight's eligible roles form a
/// cycle, so no valid order exists. Should be unreachable with correct
/// static role data; fails loud rather than silently misordering.
class NightScriptOrderConflictException implements Exception {
  final List<String> involvedRoleIds;
  NightScriptOrderConflictException(this.involvedRoleIds);

  @override
  String toString() =>
      'NightScriptOrderConflictException: circular orderConstraints among '
      'roles ${involvedRoleIds.join(', ')}';
}
