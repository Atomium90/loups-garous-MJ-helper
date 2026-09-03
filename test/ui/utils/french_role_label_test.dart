import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/ui/utils/french_role_label.dart';
import 'package:rules_engine/rules_engine.dart';

void main() {
  final registry = RoleRegistry.base;

  group('frenchRoleLabel', () {
    test('count 1 is just the singular name, no number', () {
      expect(frenchRoleLabel('voyante', 1, registry), 'Voyante');
    });

    test('Loup-Garou pluralises both words', () {
      expect(frenchRoleLabel('loup_garou', 2, registry), '2 Loups-Garous');
    });

    test('Villageois is invariable', () {
      expect(frenchRoleLabel('villageois', 3, registry), '3 Villageois');
    });
  });

  group('frenchDeckLine', () {
    test('wolves first, plain villageois last, rest in registry order between', () {
      final line = frenchDeckLine(const {
        'villageois': 2,
        'sorciere': 1,
        'loup_garou': 2,
        'cupidon': 1,
        'voyante': 1,
        'chasseur': 1,
      }, registry);

      expect(line, '2 Loups-Garous · Cupidon · Voyante · Sorcière · Chasseur · 2 Villageois');
    });

    test('drops zero-count entries', () {
      final line = frenchDeckLine(const {'loup_garou': 2, 'voyante': 0, 'villageois': 6}, registry);
      expect(line, '2 Loups-Garous · 6 Villageois');
    });
  });

  group('frenchReserveLine', () {
    test('spells each reserve card with its article, in the given order', () {
      expect(
        frenchReserveLine(const ['chasseur', 'voyante'], registry),
        'le Chasseur · la Voyante',
      );
    });

    test('is empty for no reserve', () {
      expect(frenchReserveLine(const [], registry), '');
    });
  });
}
