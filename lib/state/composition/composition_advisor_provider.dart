import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rules_engine/rules_engine.dart';

part 'composition_advisor_provider.g.dart';

/// Overridable in tests with a seeded [CompositionAdvisor] (`random: Random(1)`) for
/// deterministic suggestions.
@riverpod
CompositionAdvisor compositionAdvisor(Ref ref) => CompositionAdvisor(RoleRegistry.base);
