import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Hands a text to the system share sheet. A provider so tests can swap the sheet for a fake.
typedef TextSharer = Future<void> Function({required String text, required String subject});

final textSharerProvider = Provider<TextSharer>(
  (ref) =>
      ({required text, required subject}) async {
        await SharePlus.instance.share(ShareParams(text: text, subject: subject));
      },
);
