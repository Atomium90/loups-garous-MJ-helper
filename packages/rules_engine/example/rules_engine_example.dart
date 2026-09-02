// A scripted, non-interactive playthrough that exercises RoleRegistry,
// NightScriptBuilder and GameStateMachine together end to end. Run it with:
//   dart run example/rules_engine_example.dart
import 'package:rules_engine/rules_engine.dart';

void main() {
  final roleRegistry = RoleRegistry.base;
  const scriptBuilder = NightScriptBuilder();
  const machine = GameStateMachine();

  var state = GameState.initial(
    players: const [
      Player(id: 'alice', name: 'Alice', roleId: 'voleur'),
      Player(id: 'bob', name: 'Bob', roleId: 'cupidon'),
      Player(id: 'chloe', name: 'Chloé', roleId: 'voyante'),
      Player(id: 'david', name: 'David', roleId: 'loup_garou'),
      Player(id: 'emma', name: 'Emma', roleId: 'sorciere'),
      Player(id: 'farid', name: 'Farid', roleId: 'villageois'),
      Player(id: 'gaelle', name: 'Gaëlle', roleId: 'petite_fille'),
      Player(id: 'hugo', name: 'Hugo', roleId: 'chasseur'),
    ],
  );

  void act(GameAction action) {
    final result = machine.apply(state: state, action: action, roleRegistry: roleRegistry);
    state = result.state;
    for (final event in result.events) {
      print('    -> ${_describeEvent(event)}');
    }
  }

  void printRoster(String label) {
    print('\n--- $label ---');
    for (final p in state.players) {
      final role = roleRegistry.byId(p.roleId);
      final status = p.alive ? 'vivant' : 'mort  ';
      print('  $status  ${p.name} (${role.name})');
    }
  }

  print('=== Nuit ${state.nightIndex} ===');
  final compositionRoles = state.players.map((p) => roleRegistry.byId(p.roleId)).toList();
  final script = scriptBuilder.build(
    compositionRoles: compositionRoles,
    aliveRoleIds: state.alivePlayers.map((p) => p.roleId).toSet(),
    nightIndex: state.nightIndex,
  );
  print('Ordre d\'appel : ${script.steps.map((s) => s.role.name).join(' -> ')}');

  print('\n  Voleur (Alice) garde sa carte.');
  act(const VoleurSwap(voleurPlayerId: 'alice'));

  print('  Cupidon (Bob) désigne Farid et Gaëlle amoureux.');
  act(const CupidonPair(playerAId: 'farid', playerBId: 'gaelle'));

  final davidRole = roleRegistry.byId(state.playerById('david').roleId);
  print(
    '  Voyante (Chloé) regarde le rôle de David : ${davidRole.name}. '
    '(information privée, aucune GameAction : ça ne change pas l\'état)',
  );

  print('  Les Loups (David) désignent Hugo.');
  act(const WolvesTarget(targetPlayerId: 'hugo'));

  print('  Sorcière (Emma) ne fait rien : elle laisse Hugo mourir.');

  print('\n  On clôture la nuit.');
  act(const FinalizeNight());

  final cascade = state.cascade;
  if (cascade != null) {
    print('  Décision en attente : ${_describeDecision(cascade.decision)}');
    print('  Le Chasseur (Hugo) tire sur David en représailles.');
    act(const HunterShoot(targetPlayerId: 'david'));
  }

  printRoster('État après la nuit 1');

  print('\n=== Jour ${state.nightIndex} ===');
  print('  Le village élit Chloé capitaine.');
  act(const ElectCaptain(playerId: 'chloe'));

  print('  Le village vote et élimine Farid (amoureux de Gaëlle).');
  act(const DayVoteElimination(targetPlayerId: 'farid'));

  printRoster('État après le vote');

  final aliveWolves = state.alivePlayers.where(
    (p) => roleRegistry.byId(p.roleId).team == Team.werewolves,
  );
  if (aliveWolves.isEmpty) {
    print(
      '\nPlus aucun Loup-Garou vivant. Dans l\'app finale, ce serait le moment où le MJ verrait '
      'un signal "partie probablement terminée" — mais rien ne force la fin ici : c\'est '
      'toujours lui qui décide de continuer ou d\'arrêter. Fin de cet exemple.',
    );
    return;
  }

  print('\n  On passe à la nuit suivante.');
  act(const StartNextNight());
  printRoster('Nuit ${state.nightIndex}');
}

String _describeEvent(GameEvent event) => switch (event) {
  PlayerDied(:final playerId, :final cause) => '$playerId meurt (${_describeCause(cause)})',
  NightFinalized() => 'nuit terminée',
  LoversPaired(:final playerAId, :final playerBId) =>
    '$playerAId et $playerBId tombent amoureux',
  VoleurSwapped(:final voleurPlayerId, :final newRoleId) =>
    '$voleurPlayerId devient $newRoleId',
  RoleRevealed(:final playerId, :final roleId) => 'on découvre que $playerId est $roleId',
  CaptainElected(:final playerId) => '$playerId est élu capitaine',
  CaptainSuccession(:final fromPlayerId, :final toPlayerId) =>
    '$toPlayerId succède à $fromPlayerId comme capitaine',
  CaptainSuccessionSkipped(:final deadCaptainId) =>
    'pas de successeur pour $deadCaptainId (plus personne en vie)',
  HunterShotFired(:final hunterPlayerId, :final targetPlayerId) =>
    '$hunterPlayerId tire sur $targetPlayerId',
  HunterShotSkipped(:final hunterPlayerId) => '$hunterPlayerId ne peut tirer sur personne',
  WitchLifePotionUsed() => 'la Sorcière utilise sa potion de vie',
  WitchDeathPotionUsed(:final targetPlayerId) =>
    'la Sorcière utilise sa potion de mort sur $targetPlayerId',
};

String _describeCause(DeathCause cause) => switch (cause) {
  WolvesKill() => 'tué par les Loups',
  WitchDeathPotionKill() => 'tué par la potion de mort',
  DayVoteKill() => 'éliminé par le village',
  HunterShotKill(:final shooterPlayerId) => 'abattu par $shooterPlayerId',
  LoversCascadeKill(:final causingPlayerId) => 'meurt de chagrin après $causingPlayerId',
};

String _describeDecision(PendingDecision decision) => switch (decision) {
  PendingHunterShot(:final deadHunterId) => 'le Chasseur ($deadHunterId) doit choisir sa cible',
  PendingCaptainSuccession(:final deadCaptainId) =>
    'le Capitaine ($deadCaptainId) doit désigner son successeur',
};
