import 'dart:async';
import 'dart:math';

enum OnlineRoomStatus { waiting, ready, playing, revealing, finished, closed }

class OnlinePlayer {
  const OnlinePlayer({
    required this.id,
    required this.name,
    this.avatarId,
    this.ready = false,
    this.connected = true,
  });
  final String id;
  final String name;
  final String? avatarId;
  final bool ready;
  final bool connected;

  OnlinePlayer copyWith({bool? ready, bool? connected}) => OnlinePlayer(
    id: id,
    name: name,
    avatarId: avatarId,
    ready: ready ?? this.ready,
    connected: connected ?? this.connected,
  );
}

class OnlineRoom {
  const OnlineRoom({
    required this.code,
    required this.host,
    required this.status,
    required this.createdAt,
    required this.revision,
    this.guest,
    this.gameSetup,
    this.hostLocked = false,
    this.guestLocked = false,
    this.hostSelectionStartedAt,
    this.guestSelectionStartedAt,
    this.revealFast = false,
    this.hostBannedTeamId,
    this.guestBannedTeamId,
    this.roundId,
    this.endTime,
    this.revealStep = 0,
    this.closedBy,
    this.closeReason,
    this.closedFromStatus,
    this.closedAt,
    this.forfeitWinnerId,
    this.hostLastSeenAt,
    this.guestLastSeenAt,
  });

  final String code;
  final OnlinePlayer host;
  final OnlinePlayer? guest;
  final OnlineRoomStatus status;
  final DateTime createdAt;
  final int revision;
  final Map<String, dynamic>? gameSetup;
  final bool hostLocked;
  final bool guestLocked;
  final DateTime? hostSelectionStartedAt;
  final DateTime? guestSelectionStartedAt;
  final bool revealFast;
  final String? hostBannedTeamId;
  final String? guestBannedTeamId;
  final String? roundId;
  final DateTime? endTime;
  final int revealStep;
  final String? closedBy;
  final String? closeReason;
  final String? closedFromStatus;
  final DateTime? closedAt;
  final String? forfeitWinnerId;
  final DateTime? hostLastSeenAt;
  final DateTime? guestLastSeenAt;

  bool get bothPlayersReady => guest != null && host.ready && guest!.ready;

  OnlineRoom copyWith({
    OnlinePlayer? host,
    OnlinePlayer? guest,
    bool removeGuest = false,
    OnlineRoomStatus? status,
    int? revision,
    Map<String, dynamic>? gameSetup,
    bool? hostLocked,
    bool? guestLocked,
    DateTime? hostSelectionStartedAt,
    DateTime? guestSelectionStartedAt,
    bool? revealFast,
    String? hostBannedTeamId,
    String? guestBannedTeamId,
    String? roundId,
    DateTime? endTime,
    int? revealStep,
    String? closedBy,
    String? closeReason,
    String? closedFromStatus,
    DateTime? closedAt,
    String? forfeitWinnerId,
    DateTime? hostLastSeenAt,
    DateTime? guestLastSeenAt,
    bool resetBans = false,
    bool resetSelection = false,
  }) => OnlineRoom(
    code: code,
    host: host ?? this.host,
    guest: removeGuest ? null : guest ?? this.guest,
    status: status ?? this.status,
    createdAt: createdAt,
    revision: revision ?? this.revision,
    gameSetup: gameSetup ?? this.gameSetup,
    hostLocked: hostLocked ?? this.hostLocked,
    guestLocked: guestLocked ?? this.guestLocked,
    hostSelectionStartedAt: resetSelection
        ? null
        : hostSelectionStartedAt ?? this.hostSelectionStartedAt,
    guestSelectionStartedAt: resetSelection
        ? null
        : guestSelectionStartedAt ?? this.guestSelectionStartedAt,
    revealFast: revealFast ?? this.revealFast,
    hostBannedTeamId: resetBans
        ? null
        : hostBannedTeamId ?? this.hostBannedTeamId,
    guestBannedTeamId: resetBans
        ? null
        : guestBannedTeamId ?? this.guestBannedTeamId,
    roundId: roundId ?? this.roundId,
    endTime: endTime ?? this.endTime,
    revealStep: revealStep ?? this.revealStep,
    closedBy: closedBy ?? this.closedBy,
    closeReason: closeReason ?? this.closeReason,
    closedFromStatus: closedFromStatus ?? this.closedFromStatus,
    closedAt: closedAt ?? this.closedAt,
    forfeitWinnerId: forfeitWinnerId ?? this.forfeitWinnerId,
    hostLastSeenAt: hostLastSeenAt ?? this.hostLastSeenAt,
    guestLastSeenAt: guestLastSeenAt ?? this.guestLastSeenAt,
  );
}

class OnlineSession {
  const OnlineSession({
    required this.roomCode,
    required this.playerId,
    required this.isHost,
  });
  final String roomCode;
  final String playerId;
  final bool isHost;
}

class OnlineProfile {
  const OnlineProfile({
    required this.name,
    required this.matches,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.rating,
  });
  final String name;
  final int matches, wins, draws, losses, rating;
}

class OnlineMatchRecord {
  const OnlineMatchRecord({
    required this.opponent,
    required this.myTotal,
    required this.opponentTotal,
    required this.target,
    required this.result,
    required this.playedAt,
  });
  final String opponent, result;
  final num myTotal, opponentTotal, target;
  final DateTime playedAt;
}

abstract class OnlineGameRepository {
  Future<OnlineSession> createRoom(String playerName);
  Future<OnlineSession> joinRoom(String roomCode, String playerName);
  Stream<OnlineRoom?> watchRoom(String roomCode);
  Future<OnlineRoom?> loadRoom(String roomCode);
  Future<OnlineSession?> recoverActiveSession();
  Future<void> setPresence(OnlineSession session, bool connected);
  Future<void> cleanupStaleRooms();
  Future<void> claimDisconnectWin(OnlineSession session);
  Future<void> setReady(OnlineSession session, bool ready);
  Future<void> startRoom(OnlineSession session);
  Future<void> startSquadMatch(
    OnlineSession session,
    Map<String, dynamic> setup,
  );
  Future<void> beginSelection(OnlineSession session);
  Future<void> submitBan(OnlineSession session, String teamId);
  Future<void> submitSquad(OnlineSession session, List<dynamic> players);
  Future<void> beginReveal(OnlineSession session);
  Future<void> advanceReveal(OnlineSession session);
  Future<void> speedUpReveal(OnlineSession session);
  Future<Map<String, List<String>>> loadSquads(OnlineSession session);
  Future<OnlineSession?> findMatch(String playerName);
  Future<void> cancelMatchmaking();
  Future<OnlineProfile> loadProfile();
  Future<List<OnlineMatchRecord>> loadMatchHistory();
  Future<void> finishMatch(
    OnlineSession session,
    num hostTotal,
    num guestTotal,
    num target,
  );
  Future<void> writeDiagnosticLog({
    required String level,
    required String event,
    required String errorCode,
    required Map<String, dynamic> metadata,
  });
  Future<void> leaveRoom(OnlineSession session);
  Future<List<Map<String, dynamic>>> loadLeaderboard({int limit = 50});
}

/// Supabase bağlanana kadar oda durum makinesini tek cihazda test eder.
/// Ekranlar yalnızca [OnlineGameRepository] arayüzünü bildiği için ileride
/// bu sınıf, UI değiştirilmeden Supabase uygulamasıyla değiştirilebilir.
class LocalOnlineGameRepository implements OnlineGameRepository {
  LocalOnlineGameRepository._();
  static final LocalOnlineGameRepository instance =
      LocalOnlineGameRepository._();

  final Random _random = Random();
  final Map<String, OnlineRoom> _rooms = {};
  final Map<String, Map<String, List<String>>> _squads = {};
  final Map<String, StreamController<OnlineRoom?>> _controllers = {};

  String _id() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(999999)}';

  String _newCode() {
    for (var attempt = 0; attempt < 100; attempt++) {
      final code = (100000 + _random.nextInt(900000)).toString();
      if (!_rooms.containsKey(code)) return code;
    }
    throw StateError('Yeni oda kodu üretilemedi.');
  }

  StreamController<OnlineRoom?> _controller(String code) => _controllers
      .putIfAbsent(code, () => StreamController<OnlineRoom?>.broadcast());

  void _emit(OnlineRoom room) {
    _rooms[room.code] = room;
    _controller(room.code).add(room);
  }

  OnlineRoom _requireRoom(String code) {
    final room = _rooms[code];
    if (room == null || room.status == OnlineRoomStatus.closed) {
      throw StateError('Oda bulunamadı veya kapatılmış.');
    }
    return room;
  }

  @override
  Future<OnlineSession> createRoom(String playerName) async {
    final code = _newCode();
    final host = OnlinePlayer(id: _id(), name: playerName.trim());
    final room = OnlineRoom(
      code: code,
      host: host,
      status: OnlineRoomStatus.waiting,
      createdAt: DateTime.now(),
      revision: 1,
    );
    _emit(room);
    return OnlineSession(roomCode: code, playerId: host.id, isHost: true);
  }

  @override
  Future<OnlineSession> joinRoom(String roomCode, String playerName) async {
    final code = roomCode.replaceAll(RegExp(r'\D'), '');
    final room = _requireRoom(code);
    if (room.guest != null) throw StateError('Bu oda dolu.');
    final guest = OnlinePlayer(id: _id(), name: playerName.trim());
    _emit(room.copyWith(guest: guest, revision: room.revision + 1));
    return OnlineSession(roomCode: code, playerId: guest.id, isHost: false);
  }

  @override
  Stream<OnlineRoom?> watchRoom(String roomCode) async* {
    yield _rooms[roomCode];
    yield* _controller(roomCode).stream;
  }

  @override
  Future<OnlineRoom?> loadRoom(String roomCode) async => _rooms[roomCode];

  @override
  Future<OnlineSession?> recoverActiveSession() async => null;

  @override
  Future<void> setPresence(OnlineSession session, bool connected) async {
    final room = _rooms[session.roomCode];
    if (room == null) return;
    if (room.host.id == session.playerId) {
      _emit(
        room.copyWith(
          host: room.host.copyWith(connected: connected),
          revision: room.revision + 1,
        ),
      );
    } else if (room.guest?.id == session.playerId) {
      _emit(
        room.copyWith(
          guest: room.guest!.copyWith(connected: connected),
          revision: room.revision + 1,
        ),
      );
    }
  }

  @override
  Future<void> cleanupStaleRooms() async {}

  @override
  Future<void> claimDisconnectWin(OnlineSession session) async {
    final room = _requireRoom(session.roomCode);
    final opponent = room.host.id == session.playerId ? room.guest : room.host;
    if (opponent == null || opponent.connected) {
      throw StateError('Rakibin hâlâ bağlı.');
    }
    _emit(
      room.copyWith(
        status: OnlineRoomStatus.closed,
        revision: room.revision + 1,
        closedBy: opponent.id,
        closeReason: 'disconnect_timeout',
        closedFromStatus: room.status.name,
        closedAt: DateTime.now().toUtc(),
        forfeitWinnerId: session.playerId,
      ),
    );
  }

  @override
  Future<void> setReady(OnlineSession session, bool ready) async {
    final room = _requireRoom(session.roomCode);
    if (room.host.id == session.playerId) {
      _emit(
        room.copyWith(
          host: room.host.copyWith(ready: ready),
          revision: room.revision + 1,
        ),
      );
      return;
    }
    if (room.guest?.id == session.playerId) {
      _emit(
        room.copyWith(
          guest: room.guest!.copyWith(ready: ready),
          revision: room.revision + 1,
        ),
      );
      return;
    }
    throw StateError('Oyuncu bu odaya ait değil.');
  }

  @override
  Future<void> startRoom(OnlineSession session) async {
    final room = _requireRoom(session.roomCode);
    if (room.host.id != session.playerId) {
      throw StateError('Yalnızca oda kurucusu maçı başlatabilir.');
    }
    if (!room.bothPlayersReady) throw StateError('İki oyuncu da hazır olmalı.');
    _emit(
      room.copyWith(
        status: OnlineRoomStatus.ready,
        revision: room.revision + 1,
      ),
    );
  }

  @override
  Future<void> startSquadMatch(
    OnlineSession session,
    Map<String, dynamic> setup,
  ) async {
    final room = _requireRoom(session.roomCode);
    if (room.host.id != session.playerId || !room.bothPlayersReady) {
      throw StateError('İki oyuncu da hazır olmalı.');
    }
    _squads[room.code] = {};
    _emit(
      room.copyWith(
        status: OnlineRoomStatus.playing,
        gameSetup: setup,
        hostLocked: false,
        guestLocked: false,
        resetBans: true,
        resetSelection: true,
        revision: room.revision + 1,
      ),
    );
  }

  @override
  Future<void> submitBan(OnlineSession session, String teamId) async {
    final room = _requireRoom(session.roomCode);
    if (room.status != OnlineRoomStatus.playing) {
      throw StateError('Bu oda takım banı kabul etmiyor.');
    }
    final teams = ((room.gameSetup?['team_ids'] as List?) ?? const []).map(
      (value) => value.toString(),
    );
    if (!teams.contains(teamId)) {
      throw StateError('Bu takım kurada bulunmuyor.');
    }
    final host = room.host.id == session.playerId;
    _emit(
      room.copyWith(
        hostBannedTeamId: host ? teamId : room.hostBannedTeamId,
        guestBannedTeamId: host ? room.guestBannedTeamId : teamId,
        revision: room.revision + 1,
      ),
    );
  }

  @override
  Future<void> beginSelection(OnlineSession session) async {
    final room = _requireRoom(session.roomCode);
    final host = room.host.id == session.playerId;
    _emit(
      room.copyWith(
        hostSelectionStartedAt: host
            ? DateTime.now().toUtc()
            : room.hostSelectionStartedAt,
        guestSelectionStartedAt: host
            ? room.guestSelectionStartedAt
            : DateTime.now().toUtc(),
        revision: room.revision + 1,
      ),
    );
  }

  @override
  Future<void> submitSquad(OnlineSession session, List<dynamic> players) async {
    final room = _requireRoom(session.roomCode);
    final isHost = session.playerId == room.host.id;
    _squads[session.roomCode] ??= {};
    _squads[session.roomCode]![isHost ? 'host' : 'guest'] = players
        .map((p) => p['id'] as String)
        .toList();
    final now = DateTime.now().toUtc();
    DateTime shortened(DateTime? value) =>
        value == null || now.difference(value).inSeconds < 60
        ? now.subtract(const Duration(seconds: 60))
        : value;
    _emit(
      room.copyWith(
        hostLocked: isHost ? true : room.hostLocked,
        guestLocked: !isHost ? true : room.guestLocked,
        hostSelectionStartedAt: !isHost && !room.hostLocked
            ? shortened(room.hostSelectionStartedAt)
            : room.hostSelectionStartedAt,
        guestSelectionStartedAt: isHost && !room.guestLocked
            ? shortened(room.guestSelectionStartedAt)
            : room.guestSelectionStartedAt,
        status: (isHost ? room.guestLocked : room.hostLocked)
            ? OnlineRoomStatus.ready
            : room.status,
        revision: room.revision + 1,
      ),
    );
  }

  @override
  Future<void> beginReveal(OnlineSession session) async {
    final room = _requireRoom(session.roomCode);
    if (room.host.id != session.playerId ||
        room.status != OnlineRoomStatus.ready) {
      throw StateError('Sonuçları yalnızca oda kurucusu açabilir.');
    }
    _emit(
      room.copyWith(
        status: OnlineRoomStatus.revealing,
        revision: room.revision + 1,
      ),
    );
  }

  @override
  Future<void> advanceReveal(OnlineSession session) async {
    final room = _rooms[session.roomCode];
    if (room != null) {
      _emit(
        room.copyWith(
          revealStep: room.revealStep + 1,
          revision: room.revision + 1,
        ),
      );
    }
  }

  @override
  Future<void> speedUpReveal(OnlineSession session) async {
    final room = _rooms[session.roomCode];
    if (room != null) {
      _emit(room.copyWith(revealFast: true, revision: room.revision + 1));
    }
  }

  @override
  Future<Map<String, List<String>>> loadSquads(OnlineSession session) async => {
    for (final entry in (_squads[session.roomCode] ?? {}).entries)
      entry.key: [...entry.value],
  };

  @override
  Future<OnlineSession?> findMatch(String playerName) async => null;

  @override
  Future<void> cancelMatchmaking() async {}

  @override
  Future<OnlineProfile> loadProfile() async => const OnlineProfile(
    name: 'Yerel Oyuncu',
    matches: 0,
    wins: 0,
    draws: 0,
    losses: 0,
    rating: 1000,
  );

  @override
  Future<List<OnlineMatchRecord>> loadMatchHistory() async => const [];

  @override
  Future<void> finishMatch(
    OnlineSession session,
    num hostTotal,
    num guestTotal,
    num target,
  ) async {
    final room = _requireRoom(session.roomCode);
    if (room.host.id == session.playerId) {
      _emit(
        room.copyWith(
          status: OnlineRoomStatus.finished,
          revision: room.revision + 1,
        ),
      );
    }
  }

  @override
  Future<void> writeDiagnosticLog({
    required String level,
    required String event,
    required String errorCode,
    required Map<String, dynamic> metadata,
  }) async {}

  @override
  Future<void> leaveRoom(OnlineSession session) async {
    final room = _rooms[session.roomCode];
    if (room == null) return;
    if (room.host.id == session.playerId &&
        room.status == OnlineRoomStatus.waiting &&
        room.guest != null) {
      final promoted = room.guest!;
      _emit(
        OnlineRoom(
          code: room.code,
          host: promoted,
          status: OnlineRoomStatus.waiting,
          createdAt: room.createdAt,
          revision: room.revision + 1,
        ),
      );
      return;
    }
    if (room.host.id == session.playerId) {
      final closed = room.copyWith(
        status: OnlineRoomStatus.closed,
        revision: room.revision + 1,
        closedBy: session.playerId,
        closeReason: 'player_left',
        closedFromStatus: room.status.name,
        closedAt: DateTime.now().toUtc(),
        forfeitWinnerId: room.guest?.id,
      );
      _emit(closed);
      return;
    }
    if (room.guest?.id == session.playerId) {
      _emit(
        room.status == OnlineRoomStatus.waiting
            ? room.copyWith(
                removeGuest: true,
                status: OnlineRoomStatus.waiting,
                revision: room.revision + 1,
              )
            : room.copyWith(
                status: OnlineRoomStatus.closed,
                revision: room.revision + 1,
                closedBy: session.playerId,
                closeReason: 'player_left',
                closedFromStatus: room.status.name,
                closedAt: DateTime.now().toUtc(),
                forfeitWinnerId: room.host.id,
              ),
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> loadLeaderboard({int limit = 50}) async =>
      const [];
}
