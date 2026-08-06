import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'online_game.dart';

class SupabaseOnlineGameRepository implements OnlineGameRepository {
  Duration _timeOffset = Duration.zero;
  @override
  DateTime get serverNow => DateTime.now().toUtc().add(_timeOffset);

  void _syncTime(Map<String, dynamic> row) {
    final timestamps = [
      row['created_at'],
      row['updated_at'],
      row['host_last_seen_at'],
      row['guest_last_seen_at'],
    ]
        .where((t) => t != null)
        .map((t) => DateTime.tryParse(t.toString())?.toUtc())
        .whereType<DateTime>()
        .toList();

    if (timestamps.isNotEmpty) {
      timestamps.sort((a, b) => b.compareTo(a));
      final serverTime = timestamps.first;
      _timeOffset = serverTime.difference(DateTime.now().toUtc());
    }
  }
  SupabaseOnlineGameRepository(this.client);

  static String get projectUrl => dotenv.env['SUPABASE_URL'] ?? 'https://kapvafaeogdklovowxip.supabase.co';

  static String get publishableKey => dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ?? 'sb_publishable_Qgv56uIVc4-13j830Vvayg_DBzL6L6w';

  static bool get isConfigured {
    final uri = Uri.tryParse(projectUrl.trim());

    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        publishableKey.trim().isNotEmpty;
  }

  final SupabaseClient client;

  Future<String> _userId() async {
    var user = client.auth.currentUser;
    if (user == null) {
      final response = await client.auth.signInAnonymously();
      user = response.user;
    }
    if (user == null) {
      throw StateError(
        'Anonim oyuncu oturumu açılamadı. Supabase Anonymous Sign-Ins ayarını kontrol et.',
      );
    }
    return user.id;
  }

  Map<String, dynamic> _rpcRow(dynamic response) {
    if (response is List && response.isNotEmpty) {
      return Map<String, dynamic>.from(response.first as Map);
    }
    if (response is Map) return Map<String, dynamic>.from(response);
    throw StateError('Sunucudan geçerli oda bilgisi alınamadı.');
  }

  OnlineRoom _room(Map<String, dynamic> row) {
    final hostLastSeenAt = row['host_last_seen_at'] == null
        ? null
        : DateTime.tryParse(row['host_last_seen_at'].toString());
    final guestLastSeenAt = row['guest_last_seen_at'] == null
        ? null
        : DateTime.tryParse(row['guest_last_seen_at'].toString());

    bool isConnected(bool serverValue, 
    DateTime? lastSeenAt) {
        if (!serverValue) return false;
        if (lastSeenAt == null) return true;
        return serverNow.difference(lastSeenAt.toUtc()) 
      < const Duration(seconds: 18);
    }
    return OnlineRoom(
      code: row['code'] as String,
      host: OnlinePlayer(
        id: row['host_id'] as String,
        name: row['host_name'] as String,
        avatarId: row['host_avatar_id'] as String?,
        ready: row['host_ready'] as bool? ?? false,
        connected: isConnected(
          row['host_connected'] as bool? ?? true,
          hostLastSeenAt,
        ),
      ),
      guest: row['guest_id'] == null
          ? null
          : OnlinePlayer(
              id: row['guest_id'] as String,
              name: row['guest_name'] as String,
              avatarId: row['guest_avatar_id'] as String?,
              ready: row['guest_ready'] as bool? ?? false,
              connected: isConnected(
                row['guest_connected'] as bool? ?? true,
                guestLastSeenAt,
              ),
            ),
      status: OnlineRoomStatus.values.firstWhere(
        (value) => value.name == row['status'],
        orElse: () => OnlineRoomStatus.waiting,
      ),
      createdAt: DateTime.parse(row['created_at'] as String),
      revision: row['revision'] as int? ?? 1,
      gameSetup: row['game_setup'] == null
          ? null
          : Map<String, dynamic>.from(row['game_setup'] as Map),
      hostLocked: row['host_locked'] as bool? ?? false,
      guestLocked: row['guest_locked'] as bool? ?? false,
      hostSelectionStartedAt: row['host_selection_started_at'] == null
          ? null
          : DateTime.parse(row['host_selection_started_at'] as String),
      guestSelectionStartedAt: row['guest_selection_started_at'] == null
          ? null
          : DateTime.parse(row['guest_selection_started_at'] as String),
      revealFast: row['reveal_fast'] as bool? ?? false,
      hostBannedTeamId: row['host_banned_team_id'] as String?,
      guestBannedTeamId: row['guest_banned_team_id'] as String?,
      roundId: row['round_id']?.toString(),
      endTime: row['end_time'] == null
          ? null
          : DateTime.tryParse(row['end_time'].toString()),
      revealStep: (row['reveal_step'] as num?)?.toInt() ?? 0,
      closedBy: row['closed_by']?.toString(),
      closeReason: row['close_reason']?.toString(),
      closedFromStatus: row['closed_from_status']?.toString(),
      closedAt: row['closed_at'] == null
          ? null
          : DateTime.tryParse(row['closed_at'].toString()),
      forfeitWinnerId: row['forfeit_winner_id']?.toString(),
      hostLastSeenAt: hostLastSeenAt,
      guestLastSeenAt: guestLastSeenAt,
    );
  }

  @override
  Future<OnlineSession> createRoom(String playerName) async {
    final userId = await _userId();
    final prefs = await SharedPreferences.getInstance();
    final avatarId = prefs.getString('currentAvatar') ?? 'default';
    final row = _rpcRow(
      await client.rpc(
        'create_online_room',
        params: {'player_name': playerName.trim(), 'p_avatar_id': avatarId},
      ),
    );
    _syncTime(row);
    return OnlineSession(
      roomCode: row['code'] as String,
      playerId: userId,
      isHost: row['host_id'] == userId,
    );
  }

  @override
  Future<OnlineSession> joinRoom(String roomCode, String playerName) async {
    final userId = await _userId();
    final code = roomCode.replaceAll(RegExp(r'\D'), '');
    final active = await recoverActiveSession();
    if (active != null) {
      if (active.roomCode == code) return active;
      throw StateError(
        'Önce devam eden ${active.roomCode} numaralı odadan ayrılmalısın.',
      );
    }
    final prefs = await SharedPreferences.getInstance();
    final avatarId = prefs.getString('currentAvatar') ?? 'default';
    final row = _rpcRow(
      await client.rpc(
        'join_online_room',
        params: {
          'room_code': code,
          'player_name': playerName.trim(),
          'p_avatar_id': avatarId,
        },
      ),
    );
    _syncTime(row);
    return OnlineSession(roomCode: code, playerId: userId, isHost: false);
  }

  @override
  Stream<OnlineRoom?> watchRoom(String roomCode) async* {
    var retry = 0;
    while (true) {
      try {
        await for (final rows
            in client
                .from('online_rooms')
                .stream(primaryKey: ['code'])
                .eq('code', roomCode)) {
          retry = 0;
          yield rows.isEmpty ? null : _room(rows.first);
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      } catch (_) {
        retry++;
        yield null;
        await Future<void>.delayed(Duration(seconds: retry > 5 ? 5 : retry));
        try {
          final room = await loadRoom(roomCode);
          if (room != null) yield room;
        } catch (_) {
          // The outer loop keeps retrying until the device is online again.
        }
      }
    }
  }

  @override
  Future<OnlineRoom?> loadRoom(String roomCode) async {
    await _userId();
    final rows = await client
        .from('online_rooms')
        .select()
        .eq('code', roomCode)
        .limit(1);
    if (rows.isEmpty) return null;
    return _room(Map<String, dynamic>.from(rows.first));
  }

  @override
  Future<OnlineSession?> recoverActiveSession() async {
    final userId = await _userId();
    final response = await client.rpc('resume_online_room');
    if (response is! List || response.isEmpty) return null;
    final row = Map<String, dynamic>.from(response.first as Map);
    return OnlineSession(
      roomCode: row['code'] as String,
      playerId: userId,
      isHost: row['host_id'] == userId,
    );
  }

  @override
  Future<void> setPresence(OnlineSession session, bool connected) async {
    if (client.auth.currentUser == null) return;
    await client.rpc(
      'touch_online_presence',
      params: {'room_code': session.roomCode, 'is_connected': connected},
    );
    try {
      final rows = await client
          .from('online_rooms')
          .select('created_at, updated_at, host_last_seen_at, guest_last_seen_at')
          .eq('code', session.roomCode)
          .limit(1);
      if (rows.isNotEmpty) {
        _syncTime(rows.first);
      }
    } catch (_) {}
  }

  @override
  Future<void> cleanupStaleRooms() async {
    if (client.auth.currentUser == null) return;
    await client.rpc('cleanup_online_recovery');
  }

  @override
  Future<void> claimDisconnectWin(OnlineSession session) async {
    await _userId();
    await client.rpc(
      'claim_online_disconnect_win',
      params: {'room_code': session.roomCode},
    );
  }

  @override
  Future<void> setReady(OnlineSession session, bool ready) async {
    await _userId();
    _rpcRow(
      await client.rpc(
        'set_online_ready',
        params: {'room_code': session.roomCode, 'is_ready': ready},
      ),
    );
  }

  @override
  Future<void> startRoom(OnlineSession session) async {
    await _userId();
    _rpcRow(
      await client.rpc(
        'start_online_room',
        params: {'room_code': session.roomCode},
      ),
    );
  }

  @override
  Future<void> startSquadMatch(
    OnlineSession session,
    Map<String, dynamic> setup,
  ) async {
    await _userId();
    _rpcRow(
      await client.rpc(
        'start_online_squad_match',
        params: {'room_code': session.roomCode, 'setup': setup},
      ),
    );
  }

  @override
  Future<void> submitSquad(OnlineSession session, List<dynamic> players) async {
    await _userId();
    await client.rpc(
      'submit_online_squad',
      params: {'room_code': session.roomCode, 'selected_players': players},
    );
  }

  @override
  Future<void> beginSelection(OnlineSession session) async {
    await _userId();
    await client.rpc(
      'begin_online_selection',
      params: {'room_code': session.roomCode},
    );
  }

  @override
  Future<void> submitBan(OnlineSession session, String teamId) async {
    await _userId();
    await client.rpc(
      'submit_online_ban',
      params: {'room_code': session.roomCode, 'team_id': teamId},
    );
  }

  @override
  Future<void> beginReveal(OnlineSession session) async {
    await _userId();
    await client.rpc(
      'begin_online_reveal',
      params: {'room_code': session.roomCode},
    );
  }

  @override
  Future<void> advanceReveal(OnlineSession session) async {
    // advanceReveal is handled by delay on client side in simultaneous reveal,
    // keeping this empty or implement if server-side step is needed
  }

  @override
  Future<void> speedUpReveal(OnlineSession session) async {
    await _userId();
    await client.rpc(
      'speed_up_online_reveal',
      params: {'room_code': session.roomCode},
    );
  }

  @override
  Future<Map<String, List<String>>> loadSquads(OnlineSession session) async {
    await _userId();
    final rows = await client
        .from('online_squads')
        .select('side, player_ids')
        .eq('room_code', session.roomCode);
    final result = <String, List<String>>{};
    for (final row in rows) {
      result[row['side'] as String] = (row['player_ids'] as List)
          .map((value) => value.toString())
          .toList();
    }
    return result;
  }

  @override
  Future<OnlineSession?> findMatch(String playerName) async {
    final userId = await _userId();
    final active = await recoverActiveSession();
    if (active != null) return active;
    final prefs = await SharedPreferences.getInstance();
    final avatarId = prefs.getString('currentAvatar') ?? 'default';
    final response = await client.rpc(
      'find_online_match',
      params: {'p_player_name': playerName.trim(), 'p_avatar_id': avatarId},
    );
    if (response is! List || response.isEmpty) return null;
    final row = Map<String, dynamic>.from(response.first as Map);
    _syncTime(row);
    return OnlineSession(
      roomCode: row['code'] as String,
      playerId: userId,
      isHost: row['host_id'] == userId,
    );
  }

  @override
  Future<void> cancelMatchmaking() async {
    if (client.auth.currentUser == null) return;
    await client.rpc('cancel_online_matchmaking');
  }

  @override
  Future<OnlineProfile> loadProfile() async {
    final userId = await _userId();
    final rows = await client
        .from('online_profiles')
        .select()
        .eq('id', userId)
        .limit(1);
    if (rows.isEmpty) {
      return const OnlineProfile(
        name: 'Yeni Oyuncu',
        matches: 0,
        wins: 0,
        draws: 0,
        losses: 0,
        rating: 0,
      );
    }
    final row = rows.first;
    return OnlineProfile(
      name: row['display_name'] as String,
      matches: row['matches'] as int? ?? 0,
      wins: row['wins'] as int? ?? 0,
      draws: row['draws'] as int? ?? 0,
      losses: row['losses'] as int? ?? 0,
      rating: row['rating'] as int? ?? 0,
    );
  }

  @override
  Future<List<OnlineMatchRecord>> loadMatchHistory() async {
    final userId = await _userId();
    final rows = await client
        .from('online_match_history')
        .select()
        .or('host_id.eq.$userId,guest_id.eq.$userId')
        .order('played_at', ascending: false)
        .limit(30);
    return rows.map((row) {
      final host = row['host_id'] == userId;
      final hostTotal = row['host_total'] as num,
          guestTotal = row['guest_total'] as num;
      final winnerId = row['winner_id'] as String?;
      return OnlineMatchRecord(
        opponent: (host ? row['guest_name'] : row['host_name']) as String,
        myTotal: host ? hostTotal : guestTotal,
        opponentTotal: host ? guestTotal : hostTotal,
        target: row['target'] as num,
        result: winnerId == null
            ? 'Berabere'
            : winnerId == userId
            ? 'Galibiyet'
            : 'Mağlubiyet',
        playedAt: DateTime.parse(row['played_at'] as String),
      );
    }).toList();
  }

  @override
  Future<void> finishMatch(
    OnlineSession session,
    num hostTotal,
    num guestTotal,
    num target,
  ) async {
    await _userId();
    await client.rpc(
      'finish_online_match',
      params: {
        'room_code': session.roomCode,
        'host_total': hostTotal,
        'guest_total': guestTotal,
        'target_value': target,
      },
    );
  }

  @override
  Future<void> writeDiagnosticLog({
    required String level,
    required String event,
    required String errorCode,
    required Map<String, dynamic> metadata,
  }) async {
    await _userId();
    await client.rpc(
      'write_game_log',
      params: {
        'log_level': level,
        'event_name': event,
        'error_code': errorCode,
        'metadata': metadata,
      },
    );
  }

  @override
  Future<void> leaveRoom(OnlineSession session) async {
    if (client.auth.currentUser == null) return;
    await client.rpc(
      'leave_online_room',
      params: {'room_code': session.roomCode},
    );
  }

  @override
  Future<List<Map<String, dynamic>>> loadLeaderboard({int limit = 50}) async {
    await _userId();
    final response =
        await client.rpc('get_leaderboard', params: {'limit_count': limit})
            as List<dynamic>;
    return response
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }
}
