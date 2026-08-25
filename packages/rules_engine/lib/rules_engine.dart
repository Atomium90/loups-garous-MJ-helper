/// Pure Dart rules engine for Les Loups-Garous de Thiercelieux.
///
/// No Flutter dependency: this library must stay testable with plain
/// `dart test`, independently of the UI.
library;

export 'src/models/action_type.dart';
export 'src/models/death_effect.dart';
export 'src/models/order_constraint.dart';
export 'src/models/role.dart';
export 'src/models/team.dart';
export 'src/models/wake_condition.dart';

export 'src/role_registry/role_registry.dart';

export 'src/night_script/night_script_builder.dart';
export 'src/night_script/night_script_step.dart';

export 'src/game_state/game_state.dart';
export 'src/game_state/player.dart';
