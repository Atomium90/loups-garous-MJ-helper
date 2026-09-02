import '../game_state/death_cause.dart';
import '../game_state/game_state.dart';
import '../game_state/player.dart';

/// JSON <-> [GameState] for the app's persistence layer. Plain maps only (no
/// `dart:convert` needed here) - the caller does the `jsonEncode`/`jsonDecode`.
///
/// [CascadeState] is intentionally not handled yet: a paused death cascade only
/// exists mid-resolution of a Hunter shot / captain succession, which the app
/// does not drive over a persist boundary yet. [encode] throws if it ever sees
/// one, rather than silently dropping it.
abstract final class GameStateJson {
  static Map<String, dynamic> encode(GameState state) {
    if (state.cascade != null) {
      throw UnimplementedError(
        'GameStateJson cannot yet serialize a paused death cascade '
        '(${state.cascade.runtimeType}). It is only reachable once the death '
        'chain UI drives HunterShoot / CaptainNameSuccessor across a save.',
      );
    }
    return {
      'players': [
        for (final p in state.players)
          {
            'id': p.id,
            'name': p.name,
            'roleId': p.roleId,
            'alive': p.alive,
            'causeOfDeath': ?_encodeCause(p.causeOfDeath),
            'diedOnNight': ?p.diedOnNight,
            'diedOnPhase': ?p.diedOnPhase?.name,
          },
      ],
      'nightIndex': state.nightIndex,
      'phase': state.phase.name,
      if (state.lovers case final l?)
        'lovers': {'a': l.playerAId, 'b': l.playerBId},
      'witch': {
        'lifePotionUsed': state.witch.lifePotionUsed,
        'deathPotionUsed': state.witch.deathPotionUsed,
      },
      'captainPlayerId': ?state.captainPlayerId,
      'pendingWolfVictimId': ?state.pendingWolfVictimId,
      'pendingWitchDeathTargetId': ?state.pendingWitchDeathTargetId,
    };
  }

  static GameState decode(Map<String, dynamic> json) {
    final loversJson = json['lovers'] as Map<String, dynamic>?;
    final witchJson = (json['witch'] as Map<String, dynamic>?) ?? const {};
    return GameState(
      players: [
        for (final p in (json['players'] as List).cast<Map<String, dynamic>>())
          Player(
            id: p['id'] as String,
            name: p['name'] as String,
            roleId: p['roleId'] as String,
            alive: p['alive'] as bool,
            causeOfDeath: _decodeCause(p['causeOfDeath'] as Map<String, dynamic>?),
            diedOnNight: p['diedOnNight'] as int?,
            diedOnPhase: switch (p['diedOnPhase'] as String?) {
              null => null,
              final name => GamePhase.values.byName(name),
            },
          ),
      ],
      nightIndex: json['nightIndex'] as int,
      phase: GamePhase.values.byName(json['phase'] as String),
      lovers: loversJson == null
          ? null
          : LoversPair(loversJson['a'] as String, loversJson['b'] as String),
      witch: WitchState(
        lifePotionUsed: (witchJson['lifePotionUsed'] as bool?) ?? false,
        deathPotionUsed: (witchJson['deathPotionUsed'] as bool?) ?? false,
      ),
      captainPlayerId: json['captainPlayerId'] as String?,
      pendingWolfVictimId: json['pendingWolfVictimId'] as String?,
      pendingWitchDeathTargetId: json['pendingWitchDeathTargetId'] as String?,
    );
  }

  /// A [DeathCause] as a `{"type": ...}` map, or null for a living player.
  static Map<String, dynamic>? _encodeCause(DeathCause? cause) => switch (cause) {
    null => null,
    WolvesKill() => {'type': 'wolves'},
    WitchDeathPotionKill() => {'type': 'witchPotion'},
    DayVoteKill() => {'type': 'dayVote'},
    HunterShotKill(:final shooterPlayerId) => {
      'type': 'hunterShot',
      'shooterPlayerId': shooterPlayerId,
    },
    LoversCascadeKill(:final causingPlayerId) => {
      'type': 'loversCascade',
      'causingPlayerId': causingPlayerId,
    },
  };

  static DeathCause? _decodeCause(Map<String, dynamic>? json) => switch (json?['type']) {
    null => null,
    'wolves' => const WolvesKill(),
    'witchPotion' => const WitchDeathPotionKill(),
    'dayVote' => const DayVoteKill(),
    'hunterShot' => HunterShotKill(shooterPlayerId: json!['shooterPlayerId'] as String),
    'loversCascade' => LoversCascadeKill(causingPlayerId: json!['causingPlayerId'] as String),
    final other => throw ArgumentError('unknown death cause type: $other'),
  };
}
