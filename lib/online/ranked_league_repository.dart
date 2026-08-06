import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ranked_league.dart';
import 'online_game.dart';

abstract class RankedLeagueRepository {
  Future<CompetitiveSeason?> getActiveSeason();
  Future<List<LeagueDefinition>> getLeagueDefinitions();
  Future<SeasonLeagueRule?> getLeagueRule(String seasonId, String leagueId);
  Future<PlayerLadder?> getPlayerLadder(String seasonId, String ladderType);
  Future<ChampionsQualification?> getChampionsQualification(String seasonId);
  Future<OnlineSession?> joinRankedQueue(String ladderType, String playerName, String? avatarId);
  Future<void> cancelRankedQueue();
  Future<void> submitRankedSquad(String matchId, List<Map<String, dynamic>> payload, String idempotencyKey);
  Future<void> finalizeRankedMatch(String matchId);
  Future<List<TrophyTransaction>> getTrophyHistory(String seasonId, {int limit = 20});
  Future<List<Map<String, dynamic>>> getLeaderboard(String seasonId, String leagueId, String ladderType, {int limit = 50});
  Future<List<Map<String, dynamic>>> getChampionsTop10();
  Stream<PlayerLadder?> watchPlayerLadder(String seasonId, String ladderType);
}

class SupabaseRankedLeagueRepository implements RankedLeagueRepository {
  final SupabaseClient _client;

  SupabaseRankedLeagueRepository(this._client);

  @override
  Future<CompetitiveSeason?> getActiveSeason() async {
    try {
      final response = await _client
          .from('competitive_seasons')
          .select()
          .eq('status', 'active')
          .maybeSingle();
      if (response == null) return null;
      return CompetitiveSeason.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<LeagueDefinition>> getLeagueDefinitions() async {
    try {
      final response = await _client
          .from('league_definitions')
          .select()
          .order('tier', ascending: true);
      return (response as List).map((json) => LeagueDefinition.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<SeasonLeagueRule?> getLeagueRule(String seasonId, String leagueId) async {
    try {
      final response = await _client
          .from('season_league_rules')
          .select()
          .eq('season_id', seasonId)
          .eq('league_id', leagueId)
          .maybeSingle();
      if (response == null) return null;
      return SeasonLeagueRule.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<PlayerLadder?> getPlayerLadder(String seasonId, String ladderType) async {
    try {
      final response = await _client
          .from('player_ladders')
          .select()
          .eq('season_id', seasonId)
          .eq('ladder_type', ladderType)
          .eq('user_id', _client.auth.currentUser!.id)
          .maybeSingle();
      if (response == null) return null;
      return PlayerLadder.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<ChampionsQualification?> getChampionsQualification(String seasonId) async {
    try {
      final response = await _client
          .from('champions_qualifications')
          .select()
          .eq('season_id', seasonId)
          .eq('user_id', _client.auth.currentUser!.id)
          .maybeSingle();
      if (response == null) return null;
      return ChampionsQualification.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<OnlineSession?> joinRankedQueue(String ladderType, String playerName, String? avatarId) async {
    final response = await _client.rpc(
      'join_ranked_queue',
      params: {
        'p_ladder_type': ladderType,
        'p_player_name': playerName,
        'p_avatar_id': avatarId,
      },
    );
    if (response == null || (response as List).isEmpty) {
      return null; // Queue joined, waiting for match
    }
    
    final data = response[0] as Map<String, dynamic>;
    final roomCode = data['code'] as String;
    final hostId = data['host_id'] as String;
    
    // We determine our side
    final myId = _client.auth.currentUser?.id;
    if (myId == null) throw Exception('No user');
    final isHost = hostId == myId;
    
    final matchRes = await _client.from('ranked_matches').select('id').eq('room_code', roomCode).maybeSingle();
    
    return OnlineSession(
      roomCode: roomCode,
      playerId: myId,
      isHost: isHost,
      rankedMatchId: matchRes?['id'] as String?,
    );
  }

  @override
  Future<void> cancelRankedQueue() async {
    await _client.rpc('cancel_ranked_queue');
  }

  @override
  Future<void> submitRankedSquad(String matchId, List<Map<String, dynamic>> payload, String idempotencyKey) async {
    await _client.rpc(
      'submit_ranked_squad',
      params: {
        'p_match_id': matchId,
        'p_payload': payload,
        'p_idempotency_key': idempotencyKey,
      },
    );
  }

  @override
  Future<void> finalizeRankedMatch(String matchId) async {
    await _client.rpc(
      'finalize_ranked_match',
      params: {
        'p_match_id': matchId,
      },
    );
  }

  @override
  Future<List<TrophyTransaction>> getTrophyHistory(String seasonId, {int limit = 20}) async {
    try {
      final response = await _client
          .from('trophy_transactions')
          .select()
          .eq('season_id', seasonId)
          .eq('user_id', _client.auth.currentUser!.id)
          .order('created_at', ascending: false)
          .limit(limit);
      return (response as List).map((json) => TrophyTransaction.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getLeaderboard(String seasonId, String leagueId, String ladderType, {int limit = 50}) async {
    try {
      final response = await _client
          .from('player_ladders')
          .select('*, online_profiles(display_name, friend_code, avatar_id)')
          .eq('season_id', seasonId)
          .eq('league_id', leagueId)
          .eq('ladder_type', ladderType)
          .order('trophies', ascending: false)
          .order('wins', ascending: false)
          .order('losses', ascending: true)
          .order('peak_reached_at', ascending: true)
          .limit(limit);
      
      List<Map<String, dynamic>> result = [];
      int rank = 1;
      for (var row in (response as List)) {
        final profile = row['online_profiles'] ?? {};
        result.add({
          'rank': rank++,
          'display_name': profile['display_name'] ?? 'Oyuncu',
          'friend_code': profile['friend_code'] ?? '',
          'avatar_id': profile['avatar_id'],
          'trophies': row['trophies'],
          'wins': row['wins'],
          'matches_played': row['matches_played'],
          'user_id': row['user_id'],
        });
      }
      return result;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getChampionsTop10() async {
    try {
      final response = await _client
          .from('champions_top10_view')
          .select()
          .order('rank', ascending: true);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      return [];
    }
  }

  @override
  Stream<PlayerLadder?> watchPlayerLadder(String seasonId, String ladderType) {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return Stream.value(null);

    return _client
        .from('player_ladders')
        .stream(primaryKey: ['user_id', 'season_id'])
        .map((events) {
      final relevant = events.where((e) => e['ladder_type'] == ladderType).toList();
      if (relevant.isNotEmpty) {
        return PlayerLadder.fromJson(relevant.first);
      }
      return null;
    });
  }
}
