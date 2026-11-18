import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/l10n/localizations.dart';
import 'package:loup_garou_mj/ui/utils/labels.dart';
import 'package:rules_engine/rules_engine.dart';

void main() {
  final registry = RoleRegistry.base;
  final fr = lookupAppLocalizations(const Locale('fr'));
  final en = lookupAppLocalizations(const Locale('en'));

  group('roleCountLabel', () {
    test('count 1 is just the singular name, no number', () {
      expect(roleCountLabel(fr, 'voyante', 1), 'Voyante');
      expect(roleCountLabel(en, 'voyante', 1), 'Seer');
    });

    test('Loup-Garou pluralises both words in French', () {
      expect(roleCountLabel(fr, 'loup_garou', 2), '2 Loups-Garous');
      expect(roleCountLabel(en, 'loup_garou', 2), '2 Werewolves');
    });

    test('Villageois is invariable in French', () {
      expect(roleCountLabel(fr, 'villageois', 3), '3 Villageois');
      expect(roleCountLabel(en, 'villageois', 3), '3 Villagers');
    });
  });

  group('deckLine', () {
    const composition = {
      'villageois': 2,
      'sorciere': 1,
      'loup_garou': 2,
      'cupidon': 1,
      'voyante': 1,
      'chasseur': 1,
    };

    test('wolves first, plain villageois last, rest in registry order between', () {
      expect(
        deckLine(fr, composition, registry),
        '2 Loups-Garous · Cupidon · Voyante · Sorcière · Chasseur · 2 Villageois',
      );
      expect(
        deckLine(en, composition, registry),
        '2 Werewolves · Cupid · Seer · Witch · Hunter · 2 Villagers',
      );
    });

    test('drops zero-count entries', () {
      final line = deckLine(fr, const {'loup_garou': 2, 'voyante': 0, 'villageois': 6}, registry);

      expect(line, '2 Loups-Garous · 6 Villageois');
    });
  });

  group('reserveLine', () {
    test('spells each reserve card with its article, in the given order', () {
      expect(reserveLine(fr, const ['chasseur', 'voyante']), 'le Chasseur · la Voyante');
      expect(reserveLine(en, const ['chasseur', 'voyante']), 'the Hunter · the Seer');
    });

    test('is empty for no reserve', () {
      expect(reserveLine(fr, const []), '');
    });
  });

  group('every role of the base box', () {
    for (final role in registry.roles) {
      for (final l10n in [fr, en]) {
        test('has its texts in ${l10n.localeName}: ${role.id}', () {
          expect(l10n.roleName(role.id), isNotEmpty);
          expect(l10n.roleName(role.id), isNot(l10n.roleName('unknown')));
          expect(l10n.rolePlural(role.id), isNotEmpty);
          expect(l10n.roleWithArticle(role.id), isNotEmpty);
          expect(l10n.roleRuleText(role.id), isNotEmpty);
        });
      }
    }

    test('only Cupidon and the Sorcière carry a tip for the game master', () {
      final withTip = {
        for (final role in registry.roles)
          if (fr.roleMjTips(role.id).isNotEmpty) role.id,
      };

      expect(withTip, {'cupidon', 'sorciere'});
    });
  });

  test('an unknown role has a neutral name rather than failing', () {
    expect(fr.roleName('nouveau_role'), 'Rôle inconnu');
    expect(en.roleName('nouveau_role'), 'Unknown role');
  });
}
