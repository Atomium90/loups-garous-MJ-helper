import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/state/crash_reporting/crash_reporting.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  var started = 0;
  var stopped = 0;
  var appRuns = 0;
  final configurations = <FlutterOptionsConfiguration>[];

  void useDsn(String dsn) => CrashReporting.useForTest(
    dsn: dsn,
    start: (configure, {appRunner}) async {
      started++;
      configurations.add(configure);
      await appRunner?.call();
    },
    stop: () async => stopped++,
  );

  setUp(() {
    started = stopped = appRuns = 0;
    configurations.clear();
  });
  tearDown(CrashReporting.useForTest);

  Future<void> runApp() async => appRuns++;

  group('a build with no DSN', () {
    setUp(() => useDsn(''));

    test('cannot report: the app just runs, and nothing can be turned on', () async {
      expect(CrashReporting.available, isFalse);

      await CrashReporting.startApp(allowed: true, appRunner: runApp);
      await CrashReporting.allow(true);

      expect(appRuns, 1);
      expect(started, 0);
    });
  });

  group('a build with a DSN', () {
    setUp(() => useDsn('https://key@example.ingest.sentry.io/1'));

    test('can report, and runs the app plainly while the MJ has not allowed it', () async {
      expect(CrashReporting.available, isTrue);

      await CrashReporting.startApp(allowed: false, appRunner: runApp);

      expect(appRuns, 1);
      expect(started, 0);
    });

    test('runs the app inside Sentry when the MJ already allowed it', () async {
      await CrashReporting.startApp(allowed: true, appRunner: runApp);

      expect(started, 1);
      expect(appRuns, 1);
    });

    test('follows the choice while the app runs: starts once, stops at once', () async {
      await CrashReporting.allow(true);
      await CrashReporting.allow(true);
      expect(started, 1);

      await CrashReporting.allow(false);
      await CrashReporting.allow(false);
      expect(stopped, 1);

      await CrashReporting.allow(true);
      expect(started, 2);
    });

    test('stopping what never started does nothing', () async {
      await CrashReporting.allow(false);
      expect(stopped, 0);
    });

    test('tells Sentry to attach nothing about the games', () async {
      await CrashReporting.allow(true);
      final options = SentryFlutterOptions();

      configurations.single(options);

      expect(options.dsn, 'https://key@example.ingest.sentry.io/1');
      expect(options.sendDefaultPii, isFalse);
      expect(options.attachScreenshot, isFalse);
      expect(options.attachViewHierarchy, isFalse);
      expect(options.enableAutoSessionTracking, isFalse);
      expect(options.enableUserInteractionBreadcrumbs, isFalse);
      expect(options.enableAutoNativeBreadcrumbs, isFalse);
      expect(options.maxBreadcrumbs, 0);
      final dropped = options.beforeBreadcrumb!(Breadcrumb(message: 'Ana'), Hint());
      expect(dropped, isNull);
    });
  });
}
