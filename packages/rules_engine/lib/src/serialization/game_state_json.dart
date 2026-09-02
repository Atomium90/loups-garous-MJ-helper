import '../game_state/death_cause.dart';
import '../game_state/game_state.dart';
import '../game_state/pending_decision.dart';
import '../game_state/player.dart';

/// JSON <-> [GameState] for the app's persistence layer. Plain maps only (no
/// `dart:convert` needed here) - the caller does the `jsonEncode`/`jsonDecode`.
///
/// Covers every field, including a paused [CascadeState] (a Hunter shot or
/// captain succession the MJ can walk away from mid-resolution).
abstract final class GameStateJson {
  static Map<String, dynamic> encode(GameState state) {
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
      'cascade': ?_encodeCascade(state.cascade),
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
      cascade: _decodeCascade(json['cascade'] as Map<String, dynamic>?),
    );
  }

  static Map<String, dynamic>? _encodeCascade(CascadeState? cascade) {
    if (cascade == null) return null;
    return {
      'decision': switch (cascade.decision) {
        PendingHunterShot(:final deadHunterId) => {
          'type': 'hunterShot',
          'deadHunterId': deadHunterId,
        },
        PendingCaptainSuccession(:final deadCaptainId) => {
          'type': 'captainSuccession',
          'deadCaptainId': deadCaptainId,
        },
      },
      'remainingQueue': [
        for (final task in cascade.remainingQueue)
          {'type': _taskType(task), 'playerId': task.playerId},
      ],
    };
  }

  static CascadeState? _decodeCascade(Map<String, dynamic>? json) {
    if (json == null) return null;
    final decision = json['decision'] as Map<String, dynamic>;
    return CascadeState(
      decision: switch (decision['type']) {
        'hunterShot' => PendingHunterShot(deadHunterId: decision['deadHunterId'] as String),
        'captainSuccession' => PendingCaptainSuccession(
          deadCaptainId: decision['deadCaptainId'] as String,
        ),
        final other => throw ArgumentError('unknown pending decision type: $other'),
      },
      remainingQueue: [
        for (final t in (json['remainingQueue'] as List).cast<Map<String, dynamic>>())
          _taskFrom(t['type'] as String, t['playerId'] as String),
      ],
    );
  }

  static String _taskType(CascadeTask task) => switch (task) {
    ResolveOnDeathEffect() => 'onDeath',
    ResolveCaptainStatus() => 'captainStatus',
    ResolveLoversCascade() => 'loversCascade',
  };

  static CascadeTask _taskFrom(String type, String playerId) => switch (type) {
    'onDeath' => ResolveOnDeathEffect(playerId),
    'captainStatus' => ResolveCaptainStatus(playerId),
    'loversCascade' => ResolveLoversCascade(playerId),
    final other => throw ArgumentError('unknown cascade task type: $other'),
  };

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
