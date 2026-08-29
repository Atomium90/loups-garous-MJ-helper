import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/state/session/night_log_entry.dart';
import 'package:rules_engine/rules_engine.dart';

GameState _night({int nightIndex = 1, String? wolfVictim}) => GameState.initial(
  players: const [
    Player(id: 'a', name: 'Ana', roleId: 'loup_garou'),
    Player(id: 'b', name: 'Bo', roleId: 'sorciere'),
    Player(id: 'c', name: 'Cy', roleId: 'villageois'),
  ],
).copyWith(nightIndex: nightIndex, pendingWolfVictimId: wolfVictim);

void main() {
  test('WolvesTarget -> "Les Loups désignent {name}", tagged with the night', () {
    final lines = nightLogEntriesFor(
      const WolvesTarget(targetPlayerId: 'c'),
      _night(nightIndex: 2),
    );
    expect(lines.single.line, 'Les Loups désignent Cy');
    expect(lines.single.phaseLabel, 'NUIT 2');
    expect(lines.single.iconName, 'wolves');
  });

  test('WitchLifePotion -> "La Sorcière sauve {name}" using the pending victim', () {
    final lines = nightLogEntriesFor(const WitchLifePotion(), _night(wolfVictim: 'c'));
    expect(lines.single.line, 'La Sorcière sauve Cy');
  });

  test('WitchLifePotion with no pending victim produces nothing', () {
    expect(nightLogEntriesFor(const WitchLifePotion(), _night()), isEmpty);
  });

  test('WitchDeathPotion -> "La Sorcière empoisonne {name}"', () {
    final lines = nightLogEntriesFor(const WitchDeathPotion(targetPlayerId: 'a'), _night());
    expect(lines.single.line, 'La Sorcière empoisonne Ana');
  });

  test('FinalizeNight and identify-only actions produce no journal line', () {
    expect(nightLogEntriesFor(const FinalizeNight(), _night(wolfVictim: 'c')), isEmpty);
  });
}
