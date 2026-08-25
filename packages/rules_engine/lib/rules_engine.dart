/// Pure Dart rules engine for Loup-Garou de Thiercelieux.
///
/// No Flutter dependency: this library must stay testable with plain
/// `dart test`, independently of the UI.
library;

export 'src/models/action_type.dart';
export 'src/models/order_constraint.dart';
export 'src/models/role.dart';
export 'src/models/team.dart';
export 'src/models/wake_condition.dart';

// More exports are added here as role_registry and night_script are
// implemented.
