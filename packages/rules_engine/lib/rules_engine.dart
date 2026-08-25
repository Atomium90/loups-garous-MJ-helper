/// Pure Dart rules engine for Les Loups-Garous de Thiercelieux.
///
/// No Flutter dependency: this library must stay testable with plain
/// `dart test`, independently of the UI.
library;

export 'src/models/action_type.dart';
export 'src/models/order_constraint.dart';
export 'src/models/role.dart';
export 'src/models/team.dart';
export 'src/models/wake_condition.dart';

export 'src/role_registry/role_registry.dart';

// More exports are added here as night_script is implemented.
