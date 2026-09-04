import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/state/settings/settings_providers.dart';
import 'package:loup_garou_mj/state/settings/wakelock_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart' show wakelockPlusPlatformInstance;
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

class _FakeWakelock extends WakelockPlusPlatformInterface {
  final calls = <bool>[];
  @override
  bool get isMock => true;
  @override
  Future<void> toggle({required bool enable}) async => calls.add(enable);
  @override
  Future<bool> get enabled async => calls.isEmpty ? false : calls.last;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeWakelock fake;
  setUp(() {
    fake = _FakeWakelock();
    WakelockPlusPlatformInterface.instance = fake;
    // `wakelock_plus` caches the platform instance in a library `var` that only
    // reads `.instance` once - reset it per test too.
    wakelockPlusPlatformInstance = fake;
  });

  Future<ProviderContainer> containerWith(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    final sp = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWith((ref) async => sp)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('enables the wakelock while watched when the toggle is on', () async {
    final c = await containerWith({'keep_screen_on': true});
    final sub = c.listen(wakelockControllerProvider, (_, _) {});
    await c.read(settingsProvider.future);
    await Future<void>.delayed(Duration.zero);

    expect(fake.calls, contains(true));

    sub.close();
    await Future<void>.delayed(Duration.zero);
    expect(fake.calls.last, isFalse); // released on dispose
  });

  test('settles to disabled when the stored toggle is off', () async {
    final c = await containerWith({'keep_screen_on': false});
    final sub = c.listen(wakelockControllerProvider, (_, _) {});
    addTearDown(sub.close);
    await c.read(settingsProvider.future);
    await Future<void>.delayed(Duration.zero);

    expect(fake.calls.last, isFalse);
  });

  test('reacts to the toggle flipping while watched', () async {
    final c = await containerWith({'keep_screen_on': true});
    final sub = c.listen(wakelockControllerProvider, (_, _) {});
    addTearDown(sub.close);
    await c.read(settingsProvider.future);
    await Future<void>.delayed(Duration.zero);
    expect(fake.calls.last, isTrue);

    await c.read(settingsProvider.notifier).setKeepScreenOn(false);
    await Future<void>.delayed(Duration.zero);
    expect(fake.calls.last, isFalse);
  });
}
