import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/data/models/night_log_entry.dart';
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
  test('WolvesTarget -> the victim, tagged with the night', () {
    final lines = nightLogEntriesFor(
      const WolvesTarget(targetPlayerId: 'c'),
      _night(nightIndex: 2),
    );
    expect(lines.single.kind, JournalKind.wolvesTarget);
    expect(lines.single.args, {'player': 'Cy'});
    expect(lines.single.phase, JournalPhase.night);
    expect(lines.single.phaseIndex, 2);
    expect(lines.single.iconName, 'wolves');
  });

  test('WitchLifePotion -> the pending victim', () {
    final lines = nightLogEntriesFor(const WitchLifePotion(), _night(wolfVictim: 'c'));
    expect(lines.single.kind, JournalKind.witchSave);
    expect(lines.single.args, {'player': 'Cy'});
  });

  test('WitchLifePotion with no pending victim produces nothing', () {
    expect(nightLogEntriesFor(const WitchLifePotion(), _night()), isEmpty);
  });

  test('WitchDeathPotion -> the poisoned player', () {
    final lines = nightLogEntriesFor(const WitchDeathPotion(targetPlayerId: 'a'), _night());
    expect(lines.single.kind, JournalKind.witchPoison);
    expect(lines.single.args, {'player': 'Ana'});
  });

  test('Cupidon, the Voleur and the Chasseur each journal who and what', () {
    final cupid = nightLogEntriesFor(
      const CupidonPair(playerAId: 'a', playerBId: 'b'),
      _night(),
    ).single;
    expect(cupid.kind, JournalKind.cupidPair);
    expect(cupid.args, {'player': 'Ana', 'other': 'Bo'});

    final keep = nightLogEntriesFor(const VoleurSwap(voleurPlayerId: 'c'), _night()).single;
    expect(keep.kind, JournalKind.thiefKeep);

    final swap = nightLogEntriesFor(
      const VoleurSwap(voleurPlayerId: 'c', stolenRoleId: 'voyante'),
      _night(),
    ).single;
    expect(swap.kind, JournalKind.thiefSwap);
    expect(swap.args, {'role': 'voyante'});

    expect(
      nightLogEntriesFor(const HunterShoot(targetPlayerId: null), _night()).single.kind,
      JournalKind.hunterNoShot,
    );
    expect(
      nightLogEntriesFor(const HunterShoot(targetPlayerId: 'b'), _night()).single.args,
      {'player': 'Bo'},
    );
  });

  test('FinalizeNight and identify-only actions produce no journal line', () {
    expect(nightLogEntriesFor(const FinalizeNight(), _night(wolfVictim: 'c')), isEmpty);
  });
}
