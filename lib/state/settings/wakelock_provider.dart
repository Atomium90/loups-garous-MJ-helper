import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'settings_providers.dart';

part 'wakelock_provider.g.dart';

/// Best-effort: a platform without a wakelock (or a test harness) just no-ops.
Future<void> _applyWakelock(bool enable) async {
  try {
    await WakelockPlus.toggle(enable: enable);
  } catch (_) {
    // no plugin on this platform / in tests - nothing to keep awake
  }
}

/// Holds the screen awake while it is watched (the in-game shell mounts it),
/// as long as the "Garder l'écran allumé" setting is on. Disposing - leaving
/// the game - releases it. autoDispose, so it is scoped to the shell's life.
@riverpod
void wakelockController(Ref ref) {
  final keepOn = ref.watch(settingsProvider).value?.keepScreenOn ?? true;
  _applyWakelock(keepOn);
  ref.onDispose(() => _applyWakelock(false));
}
