import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rules_engine/rules_engine.dart';

import '../settings/settings_providers.dart';

part 'composition_advisor_provider.g.dart';

/// Overridable in tests with a seeded [CompositionAdvisor] (`random: Random(1)`) for
/// deterministic suggestions.
@riverpod
CompositionAdvisor compositionAdvisor(Ref ref) => CompositionAdvisor(ref.watch(cardPoolProvider));
