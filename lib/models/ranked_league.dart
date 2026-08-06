import 'package:flutter/material.dart';

class LeagueDefinition {
  final String id;
  final String displayName;
  final int tier;
  final int baseTrophies;
  final int? promotionTrophies;
  final int? promotionMinMatches;
  final bool isChampions;
  final Color color;

  LeagueDefinition({
    required this.id,
    required this.displayName,
    required this.tier,
    required this.baseTrophies,
    this.promotionTrophies,
    this.promotionMinMatches,
    required this.isChampions,
    required this.color,
  });

  factory LeagueDefinition.fromJson(Map<String, dynamic> json) {
    Color parsedColor = Colors.grey;
    if (json['color_hex'] != null) {
      final hex = (json['color_hex'] as String).replaceAll('#', '');
      if (hex.length == 6) {
        parsedColor = Color(int.parse('FF$hex', radix: 16));
      }
    }
    return LeagueDefinition(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
      tier: json['tier'] as int,
      baseTrophies: json['base_trophies'] as int,
      promotionTrophies: json['promotion_trophies'] as int?,
      promotionMinMatches: json['promotion_min_matches'] as int?,
      isChampions: json['is_champions'] as bool? ?? false,
      color: parsedColor,
    );
  }
}

class CompetitiveSeason {
  final String id;
  final String status;
  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime? queueLockedAt;
  final DateTime? closedAt;

  CompetitiveSeason({
    required this.id,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    this.queueLockedAt,
    this.closedAt,
  });

  factory CompetitiveSeason.fromJson(Map<String, dynamic> json) {
    return CompetitiveSeason(
      id: json['id'] as String,
      status: json['status'] as String,
      startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
      endsAt: DateTime.parse(json['ends_at'] as String).toLocal(),
      queueLockedAt: json['queue_locked_at'] != null ? DateTime.parse(json['queue_locked_at'] as String).toLocal() : null,
      closedAt: json['closed_at'] != null ? DateTime.parse(json['closed_at'] as String).toLocal() : null,
    );
  }
}

class PlayerLadder {
  final String userId;
  final String seasonId;
  final String leagueId;
  final String ladderType;
  final int trophies;
  final int matchesPlayed;
  final int wins;
  final int draws;
  final int losses;
  final int peakTrophies;

  PlayerLadder({
    required this.userId,
    required this.seasonId,
    required this.leagueId,
    required this.ladderType,
    required this.trophies,
    required this.matchesPlayed,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.peakTrophies,
  });

  factory PlayerLadder.fromJson(Map<String, dynamic> json) {
    return PlayerLadder(
      userId: json['user_id'] as String,
      seasonId: json['season_id'] as String,
      leagueId: json['league_id'] as String,
      ladderType: json['ladder_type'] as String,
      trophies: json['trophies'] as int,
      matchesPlayed: json['matches_played'] as int,
      wins: json['wins'] as int,
      draws: json['draws'] as int,
      losses: json['losses'] as int,
      peakTrophies: json['peak_trophies'] as int,
    );
  }
}

class ChampionsQualification {
  final String userId;
  final String seasonId;
  final DateTime qualifiedAt;
  final int trophiesAtQualification;
  final int matchesAtQualification;

  ChampionsQualification({
    required this.userId,
    required this.seasonId,
    required this.qualifiedAt,
    required this.trophiesAtQualification,
    required this.matchesAtQualification,
  });

  factory ChampionsQualification.fromJson(Map<String, dynamic> json) {
    return ChampionsQualification(
      userId: json['user_id'] as String,
      seasonId: json['season_id'] as String,
      qualifiedAt: DateTime.parse(json['qualified_at'] as String).toLocal(),
      trophiesAtQualification: json['trophies_at_qualification'] as int,
      matchesAtQualification: json['matches_at_qualification'] as int,
    );
  }
}

class SeasonLeagueRule {
  final int winTrophies;
  final int drawTrophies;
  final int lossTrophies;
  final int promotionRewardCoins;
  final int championsUnlockTrophies;
  final int championsUnlockMatches;

  SeasonLeagueRule({
    required this.winTrophies,
    required this.drawTrophies,
    required this.lossTrophies,
    required this.promotionRewardCoins,
    required this.championsUnlockTrophies,
    required this.championsUnlockMatches,
  });

  factory SeasonLeagueRule.fromJson(Map<String, dynamic> json) {
    return SeasonLeagueRule(
      winTrophies: json['win_trophies'] as int,
      drawTrophies: json['draw_trophies'] as int,
      lossTrophies: json['loss_trophies'] as int,
      promotionRewardCoins: json['promotion_reward_coins'] as int,
      championsUnlockTrophies: json['champions_unlock_trophies'] as int? ?? 1300,
      championsUnlockMatches: json['champions_unlock_matches'] as int? ?? 20,
    );
  }
}

class TrophyTransaction {
  final String id;
  final String matchId;
  final int delta;
  final int baseDelta;
  final double antiFarmFactor;
  final int oldTrophies;
  final int newTrophies;
  final String result;
  final DateTime createdAt;

  TrophyTransaction({
    required this.id,
    required this.matchId,
    required this.delta,
    required this.baseDelta,
    required this.antiFarmFactor,
    required this.oldTrophies,
    required this.newTrophies,
    required this.result,
    required this.createdAt,
  });

  factory TrophyTransaction.fromJson(Map<String, dynamic> json) {
    return TrophyTransaction(
      id: json['id'].toString(),
      matchId: json['match_id'] as String,
      delta: json['delta'] as int,
      baseDelta: json['base_delta'] as int,
      antiFarmFactor: (json['anti_farm_factor'] as num).toDouble(),
      oldTrophies: json['old_trophies'] as int,
      newTrophies: json['new_trophies'] as int,
      result: json['result'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}

class RankedMatchResult {
  final int oldTrophies;
  final int baseDelta;
  final double antiFarmFactor;
  final int newTrophies;
  final String result; // win, draw, loss
  final String leagueName;
  final bool qualifiedForChampions;

  RankedMatchResult({
    required this.oldTrophies,
    required this.baseDelta,
    required this.antiFarmFactor,
    required this.newTrophies,
    required this.result,
    required this.leagueName,
    required this.qualifiedForChampions,
  });
}
