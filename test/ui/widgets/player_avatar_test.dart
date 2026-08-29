import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/ui/theme/app_colors.dart';
import 'package:loup_garou_mj/ui/widgets/player_avatar.dart';

import '../../support/pump_app.dart';

void main() {
  group('initialsOf', () {
    test('takes the first two letters, uppercased', () {
      expect(PlayerAvatar.initialsOf('Camille'), 'CA');
      expect(PlayerAvatar.initialsOf('jo'), 'JO');
      expect(PlayerAvatar.initialsOf('  élise  '), 'ÉL');
    });

    test('a one-letter name yields one initial', () {
      expect(PlayerAvatar.initialsOf('A'), 'A');
    });

    test('an empty or blank name yields no initials', () {
      expect(PlayerAvatar.initialsOf(''), '');
      expect(PlayerAvatar.initialsOf('   '), '');
    });
  });

  testWidgets('unselected renders the initials over the given fill', (tester) async {
    await pumpApp(tester, const PlayerAvatar(name: 'Julien', fillColor: Color(0xFFFFFFFF)));

    expect(find.text('JU'), findsOneWidget);
    final container = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFFFFFFFF));
    expect(decoration.border! as Border, isNotNull);
  });

  testWidgets('selected renders the accent ring/fill/text', (tester) async {
    await pumpApp(tester, const PlayerAvatar(name: 'Awa', selected: true));

    final container = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.light.accentBg);
    final border = decoration.border! as Border;
    expect(border.top.color, AppColors.light.accentBorder);
    expect(border.top.width, 2);

    final text = tester.widget<Text>(find.text('AW'));
    expect(text.style?.color, AppColors.light.accentText);
  });

  testWidgets('a blank name renders an empty circle', (tester) async {
    await pumpApp(tester, const PlayerAvatar(name: ''));
    expect(find.text(''), findsOneWidget);
  });
}
