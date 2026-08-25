import 'package:collection/collection.dart';

import 'pending_decision.dart';
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

  /// Non-null exactly while a death cascade is paused on a Hunter/Captain
  /// choice only the MJ can make.
  final CascadeState? cascade;

  const GameState({
    required this.players,
    required this.nightIndex,
    required this.phase,
    this.lovers,
    this.witch = const WitchState(),
    this.captainPlayerId,
    this.pendingWolfVictimId,
    this.pendingWitchDeathTargetId,
    this.cascade,
  });

  factory GameState.initial({required List<Player> players}) =>
      GameState(players: players, nightIndex: 1, phase: GamePhase.night);

  Player playerById(String id) =>
      players.firstWhereOrNull((p) => p.id == id) ?? (throw PlayerNotFoundException(id));

  List<Player> get alivePlayers => players.where((p) => p.alive).toList(growable: false);

  /// Marks [playerId] as dead. Does not resolve any cascade effects; that's
  /// the death cascade's job (see death_cascade.dart).
  GameState killPlayer(String playerId) {
    playerById(playerId); // validates existence
    return copyWith(
      players: [
        for (final p in players)
          if (p.id == playerId) p.copyWith(alive: false) else p,
      ],
    );
  }

  GameState copyWith({
    List<Player>? players,
    int? nightIndex,
    GamePhase? phase,
    Object? lovers = _unset,
    WitchState? witch,
    Object? captainPlayerId = _unset,
    Object? pendingWolfVictimId = _unset,
    Object? pendingWitchDeathTargetId = _unset,
    Object? cascade = _unset,
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
    cascade: identical(cascade, _unset) ? this.cascade : cascade as CascadeState?,
  );
}
