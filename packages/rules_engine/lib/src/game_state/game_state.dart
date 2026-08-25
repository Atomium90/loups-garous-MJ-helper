import 'package:collection/collection.dart';

import 'player.dart';

enum GamePhase { night, day }

class WitchState {
  final bool lifePotionUsed;
  final bool deathPotionUsed;

  const WitchState({this.lifePotionUsed = false, this.deathPotionUsed = false});

  WitchState copyWith({bool? lifePotionUsed, bool? deathPotionUsed}) => WitchState(
    lifePotionUsed: lifePotionUsed ?? this.lifePotionUsed,
    deathPotionUsed: deathPotionUsed ?? this.deathPotionUsed,
  );
}

class LoversPair {
  final String playerAId;
  final String playerBId;

  const LoversPair(this.playerAId, this.playerBId);

  /// The other lover's id, or null if [playerId] is neither of them.
  String? partnerOf(String playerId) {
    if (playerId == playerAId) return playerBId;
    if (playerId == playerBId) return playerAId;
    return null;
  }
}

/// Sentinel for [GameState.copyWith]'s nullable fields, so a caller can
/// distinguish "leave unchanged" (the default) from "set to null"
/// (pass `null` explicitly), which a plain `field ?? this.field` can't do.
const _unset = Object();

class GameState {
  final List<Player> players;

  /// 1-based, same convention as NightScriptBuilder.
  final int nightIndex;
  final GamePhase phase;

  /// Null until Cupidon acts.
  final LoversPair? lovers;
  final WitchState witch;
  final String? captainPlayerId;

  /// Set by WolvesTarget, cleared by FinalizeNight.
  final String? pendingWolfVictimId;

  /// Set by WitchDeathPotion, cleared by FinalizeNight.
  final String? pendingWitchDeathTargetId;

  const GameState({
    required this.players,
    required this.nightIndex,
    required this.phase,
    this.lovers,
    this.witch = const WitchState(),
    this.captainPlayerId,
    this.pendingWolfVictimId,
    this.pendingWitchDeathTargetId,
  });

  factory GameState.initial({required List<Player> players}) =>
      GameState(players: players, nightIndex: 1, phase: GamePhase.night);

  Player playerById(String id) =>
      players.firstWhereOrNull((p) => p.id == id) ?? (throw PlayerNotFoundException(id));

  List<Player> get alivePlayers => players.where((p) => p.alive).toList(growable: false);

  GameState copyWith({
    List<Player>? players,
    int? nightIndex,
    GamePhase? phase,
    Object? lovers = _unset,
    WitchState? witch,
    Object? captainPlayerId = _unset,
    Object? pendingWolfVictimId = _unset,
    Object? pendingWitchDeathTargetId = _unset,
  }) => GameState(
    players: players ?? this.players,
    nightIndex: nightIndex ?? this.nightIndex,
    phase: phase ?? this.phase,
    lovers: identical(lovers, _unset) ? this.lovers : lovers as LoversPair?,
    witch: witch ?? this.witch,
    captainPlayerId: identical(captainPlayerId, _unset)
        ? this.captainPlayerId
        : captainPlayerId as String?,
    pendingWolfVictimId: identical(pendingWolfVictimId, _unset)
        ? this.pendingWolfVictimId
        : pendingWolfVictimId as String?,
    pendingWitchDeathTargetId: identical(pendingWitchDeathTargetId, _unset)
        ? this.pendingWitchDeathTargetId
        : pendingWitchDeathTargetId as String?,
  );
}
