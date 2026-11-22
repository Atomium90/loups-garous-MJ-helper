import 'dart:async';

import 'package:sentry_flutter/sentry_flutter.dart';

/// Where the crash reports go: the DSN of the Sentry project, given when the app is built
/// (`--dart-define=SENTRY_DSN=...`). Empty in a build that has none (development, tests): the app
/// then never reports anything and the setting is not shown.
const kSentryDsn = String.fromEnvironment('SENTRY_DSN');

/// The preference key of the MJ's choice. Off until they turn it on.
const kCrashReportsPref = 'crash_reports';

/// Crash reports, strictly opt-in: Sentry is only running while the MJ allows it, and it is told
/// to keep everything about the games out of what it sends (no names, no screenshots, no trail of
/// what was tapped, no user, no sessions).
class CrashReporting {
  const CrashReporting._();

  static bool _running = false;

  /// Whether this build knows where to send reports.
  static bool get available => kSentryDsn.isNotEmpty;

  /// Starts Sentry around the app when the MJ already allowed it; otherwise just runs the app.
  static Future<void> startApp({required bool allowed, required FutureOr<void> Function() appRunner}) async {
    if (!available || !allowed) {
      await appRunner();
      return;
    }
    _running = true;
    await SentryFlutter.init(_configure, appRunner: appRunner);
  }

  /// Follows the MJ's choice while the app runs: turning it on starts Sentry, turning it off stops
  /// it at once.
  static Future<void> allow(bool allowed) async {
    if (!available) return;
    if (allowed && !_running) {
      _running = true;
      await SentryFlutter.init(_configure);
    } else if (!allowed && _running) {
      _running = false;
      await Sentry.close();
    }
  }

  static void _configure(SentryFlutterOptions options) {
    options
      ..dsn = kSentryDsn
      ..sendDefaultPii = false
      ..attachScreenshot = false
      ..attachViewHierarchy = false
      ..enableAutoSessionTracking = false
      ..enableUserInteractionBreadcrumbs = false
      ..enableAutoNativeBreadcrumbs = false
      ..reportPackages = false
      ..maxBreadcrumbs = 0
      ..beforeBreadcrumb = (breadcrumb, hint) => null;
  }
}
