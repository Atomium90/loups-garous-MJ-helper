import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// The message keys of an ARB file: everything but the `@@locale` / `@key` metadata.
Set<String> _messageKeys(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();

/// Whether [message] uses the placeholder [name], on its own (`{name}`) or as the argument of
/// a plural or select (`{name, plural, ...}`).
bool _uses(String message, String name) => RegExp('\\{$name[,}]').hasMatch(message);

void main() {
  final fr = _read('lib/l10n/app_fr.arb');
  final en = _read('lib/l10n/app_en.arb');

  test('French and English have the same messages', () {
    final frKeys = _messageKeys(fr);
    final enKeys = _messageKeys(en);

    expect(enKeys.difference(frKeys), isEmpty, reason: 'in English only');
    expect(frKeys.difference(enKeys), isEmpty, reason: 'in French only');
  });

  test('every message has a description for the translators, in the template only', () {
    for (final key in _messageKeys(fr)) {
      final meta = fr['@$key'] as Map<String, dynamic>?;
      expect(meta?['description'], isA<String>(), reason: '$key has no description');
    }
    expect(en.keys.where((k) => k.startsWith('@') && k != '@@locale'), isEmpty);
  });

  test('both languages use the same placeholders in every message', () {
    for (final key in _messageKeys(fr)) {
      final meta = fr['@$key'] as Map<String, dynamic>?;
      final placeholders = (meta?['placeholders'] as Map<String, dynamic>?)?.keys ?? const [];
      for (final name in placeholders) {
        expect(
          _uses(en[key] as String, name),
          _uses(fr[key] as String, name),
          reason: '$key: "$name" is used in one language and not the other',
        );
      }
    }
  });

  test('no message is empty', () {
    for (final arb in [fr, en]) {
      for (final key in _messageKeys(arb)) {
        expect((arb[key] as String).trim(), isNotEmpty, reason: key);
      }
    }
  });
}
