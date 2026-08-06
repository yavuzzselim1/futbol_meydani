import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math';
import '../../utils/helpers.dart';
import '../../online/online_game.dart';
import '../../screens/match_screen.dart';
import '../../screens/ranked_result_screen.dart';

import 'package:futbol_meydani/widgets/common_widgets.dart';
import 'package:futbol_meydani/utils/glass_toast.dart';

import 'package:futbol_meydani/services/game_store.dart';
import 'package:futbol_meydani/services/ranked_league_store.dart';

import '../../globals.dart';
import '../../constants.dart';
import '../../models/game_data.dart';
import '../../models/multi_league.dart';
import '../../widgets/common_widgets.dart';

import '../../screens/squad_challenge_screen.dart';
import '../squad_pitch.dart';
import 'online_presence_scope.dart';

class OnlineSquadScreen extends StatefulWidget {
  const OnlineSquadScreen({
    super.key,
    required this.data,
    required this.repository,
    required this.session,
    required this.initialRoom,
    this.isRanked = false,
  });
  final GameData data;
  final OnlineGameRepository repository;
  final OnlineSession session;
  final OnlineRoom initialRoom;
  final bool isRanked;
  @override
  State<OnlineSquadScreen> createState() => _OnlineSquadScreenState();
}

class _OnlineSquadScreenState extends State<OnlineSquadScreen> {
  final search = TextEditingController();
  final selected = <Pick>[];
  late OnlineRoom room;
  late LeagueDrawRound draw;
  late Formation formation;
  late List<Pick> suggestions;
  StreamSubscription<OnlineRoom?>? subscription;
  Timer? timer;
  Timer? clockTimer;
  Timer? reconnectTimer;
  int secondsLeft = 120;
  OnlineSquadPhase phase = OnlineSquadPhase.draw;
  Map<String, List<Pick>> squads = const {'host': [], 'guest': []};
  List<int> revealed = [0, 0];
  bool revealing = false;
  Pick? spotlight;
  int spotlightSide = 0;
  bool spotlightValue = false;
  late String setupKey;
  bool connectionLost = false;
  bool submittingBan = false;
  bool beginningSelection = false;
  bool timeReductionNotified = false;
  bool resultRecorded = false;
  bool get opponentConnected =>
      isLeader ? room.guest?.connected ?? false : room.host.connected;
  DateTime? get opponentLastSeen =>
      isLeader ? room.guestLastSeenAt : room.hostLastSeenAt;
  bool get disconnectWinAvailable {
    final lastSeen = opponentLastSeen;
    return !opponentConnected &&
        lastSeen != null &&
        widget.repository.serverNow.difference(lastSeen.toUtc()).inSeconds >= 60;
  }

  Map<String, dynamic> get setup => room.gameSetup!;
  bool get isLeader => room.host.id == widget.session.playerId;
  String get mySide => isLeader ? 'host' : 'guest';
  List<Pick> get allCandidates => draw.candidates
      .map((player) => Pick(player, player.stats[draw.metric] ?? 0))
      .toList();
  String? get myBan =>
      isLeader ? room.hostBannedTeamId : room.guestBannedTeamId;
  String? get opponentBan =>
      isLeader ? room.guestBannedTeamId : room.hostBannedTeamId;
  bool get bothBansReady =>
      room.hostBannedTeamId != null && room.guestBannedTeamId != null;
  List<Pick> get candidates =>
      allCandidates.where((pick) => pick.player.teamId != opponentBan).toList();
  List<String> get allowedTeamNames => [
    for (var index = 0; index < draw.teamIds.length; index++)
      if (draw.teamIds[index] != opponentBan) draw.teamNames[index],
  ];

  @override
  void initState() {
    super.initState();
    room = widget.initialRoom;
    configureDraw();
    setupKey = room.roundId ?? onlineSetupKey(room.gameSetup);
    if (room.status == OnlineRoomStatus.ready ||
        (room.hostLocked && isLeader) ||
        (room.guestLocked && !isLeader)) {
      phase = OnlineSquadPhase.waiting;
    }
    listenRoom();
    clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted &&
          (phase == OnlineSquadPhase.waiting || !opponentConnected)) {
        setState(() {});
      }
    });
    if (room.status == OnlineRoomStatus.revealing ||
        room.status == OnlineRoomStatus.finished) {
      loadResults();
    }
  }

  void listenRoom() {
    subscription?.cancel();
    subscription = widget.repository
        .watchRoom(widget.session.roomCode)
        .listen(
          (value) {
            if (!mounted) return;
            if (value == null) {
              setState(() => connectionLost = true);
              return;
            }
            reconnectTimer?.cancel();
            connectionLost = false;
            final nextSetupKey =
                value.roundId ?? onlineSetupKey(value.gameSetup);
            if (value.status == OnlineRoomStatus.playing &&
                nextSetupKey != setupKey) {
              room = value;
              setupKey = nextSetupKey;
              resetForRematch();
              return;
            }
            room = value;
            if (value.status == OnlineRoomStatus.closed) {
              unawaited(clearActiveOnlineSession());
              setState(() {});
              return;
            }
            if (phase == OnlineSquadPhase.banning &&
                bothBansReady &&
                !beginningSelection) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => beginSelection(),
              );
            }
            if (phase == OnlineSquadPhase.selection) {
              final endTime = value.endTime;
              if (endTime != null) {
                final serverRemaining = max(
                  0,
                  endTime.toUtc().difference(widget.repository.serverNow).inSeconds,
                );
                if (serverRemaining < secondsLeft) {
                  secondsLeft = serverRemaining;
                }
              }
              final opponentLocked = isLeader
                  ? value.guestLocked
                  : value.hostLocked;
              if (opponentLocked && secondsLeft > 15) {
                if (!timeReductionNotified) {
                  timeReductionNotified = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      GlassToast.show(context, 'Rakibin kadrosunu tamamladı! Kalan süren hızlandırıldı.', isError: false);
                    }
                  });
                }
                secondsLeft = 15;
              }
            }
            if (value.status == OnlineRoomStatus.revealing ||
                value.status == OnlineRoomStatus.finished) {
              loadResults();
            } else {
              setState(() {});
            }
          },
          onError: (error) {
            unawaited(
              diagnostics.record(
                level: 'warning',
                event: 'online_stream_disconnected',
                errorCode: 'FM-ONL-008',
                metadata: {'kind': error.runtimeType.toString()},
                repository: widget.repository,
              ),
            );
            if (mounted) {
              setState(() => connectionLost = true);
              scheduleReconnect();
            }
          },
          onDone: () {
            unawaited(
              diagnostics.record(
                level: 'warning',
                event: 'online_stream_closed',
                errorCode: 'FM-ONL-008',
                repository: widget.repository,
              ),
            );
            if (mounted) {
              setState(() => connectionLost = true);
              scheduleReconnect();
            }
          },
        );
  }

  void scheduleReconnect() {
    reconnectTimer?.cancel();
    reconnectTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      listenRoom();
    });
  }

  Future<void> claimDisconnectWin() async {
    try {
      await widget.repository.claimDisconnectWin(widget.session);
      gameStore.tap(GameSound.win);
    } catch (error) {
      if (!mounted) return;
      GlassToast.show(context, error.toString().replaceFirst('PostgrestException(message: ', ''), isError: true);
    }
  }

  void resetForRematch() {
    timer?.cancel();
    selected.clear();
    search.clear();
    secondsLeft = 120;
    phase = OnlineSquadPhase.draw;
    squads = const {'host': [], 'guest': []};
    revealed = [0, 0];
    revealing = false;
    submittingBan = false;
    beginningSelection = false;
    timeReductionNotified = false;
    resultRecorded = false;
    spotlight = null;
    spotlightValue = false;
    configureDraw();
    if (mounted) setState(() {});
  }

  void configureDraw() {
    final ids = (setup['candidate_ids'] as List)
        .map((value) => value.toString())
        .toList();
    final players = ids
        .map((id) => widget.data.multiLeague!.players[id])
        .whereType<Player>()
        .toList();
    draw = LeagueDrawRound(
      metric: setup['metric'] as String,
      title: setup['title'] as String,
      unit: setup['unit'] as String,
      prompt: setup['prompt'] as String,
      leagueId: setup['league_id'] as String,
      leagueName: setup['league_name'] as String,
      teamIds: (setup['team_ids'] as List)
          .map((value) => value.toString())
          .toList(),
      teamNames: (setup['team_names'] as List)
          .map((value) => value.toString())
          .toList(),
      target: (setup['target'] as num).round(),
      candidates: players,
    );
    final f = Map<String, dynamic>.from(setup['formation'] as Map);
    formation = Formation(
      (f['gk'] as num).toInt(),
      (f['df'] as num).toInt(),
      (f['mf'] as num).toInt(),
      (f['fw'] as num).toInt(),
      f['label'] as String,
    );
    configureSuggestions();
  }

  void configureSuggestions() {
    final ranked = [...candidates]..sort((a, b) => b.value.compareTo(a.value));
    final related = ranked.take(2).toList();
    final relatedIds = related.map((pick) => pick.player.id).toSet();
    final randoms =
        candidates
            .where((pick) => !relatedIds.contains(pick.player.id))
            .toList()
          ..shuffle(Random());
    suggestions = [...randoms.take(5), ...related]..shuffle(Random());
  }

  Future<void> beginSelection() async {
    if (beginningSelection || !bothBansReady) return;
    beginningSelection = true;
    final existingEnd = room.endTime;
    try {
      await widget.repository.beginSelection(widget.session);
      if (!mounted) return;
      configureSuggestions();
      secondsLeft = existingEnd == null
          ? 120
          : max(
              0,
              existingEnd.toUtc().difference(widget.repository.serverNow).inSeconds,
            );
      setState(() => phase = OnlineSquadPhase.selection);
      timer?.cancel();
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || phase != OnlineSquadPhase.selection) return;
        if (secondsLeft <= 1) {
          gameStore.warning();
          setState(() => secondsLeft = 0);
          submit();
        } else {
          if (secondsLeft <= 11) gameStore.countdown();
          setState(() => secondsLeft--);
        }
      });
    } catch (error) {
      unawaited(
        diagnostics.record(
          level: 'error',
          event: 'online_selection_start_failed',
          errorCode: 'FM-ONL-010',
          metadata: {'kind': error.runtimeType.toString()},
          repository: widget.repository,
        ),
      );
      if (mounted) {
        GlassToast.show(context, 'Kadro seçimi başlatılamadı. Destek kodu: FM-ONL-010', isError: true);
      }
    } finally {
      beginningSelection = false;
    }
  }

  void openBanPhase() {
    setState(() => phase = OnlineSquadPhase.banning);
    if (bothBansReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) => beginSelection());
    }
  }

  bool banLeavesValidSquad(String teamId) {
    final remaining = allCandidates.where(
      (pick) => pick.player.teamId != teamId,
    );
    return ['GK', 'DF', 'MF', 'FW'].every(
      (position) =>
          remaining.where((pick) => pick.player.position == position).length >=
          formation.quota(position),
    );
  }

  Future<void> submitBan(String teamId) async {
    if (submittingBan || myBan != null || !banLeavesValidSquad(teamId)) return;
    setState(() => submittingBan = true);
    try {
      await widget.repository.submitBan(widget.session, teamId);
      unawaited(
        diagnostics.record(
          level: 'info',
          event: 'online_team_banned',
          repository: widget.repository,
        ),
      );
      gameStore.tap(GameSound.lock);
    } catch (error) {
      unawaited(
        diagnostics.record(
          level: 'error',
          event: 'online_ban_failed',
          errorCode: 'FM-ONL-006',
          metadata: {'kind': error.runtimeType.toString()},
          repository: widget.repository,
        ),
      );
      if (mounted) {
        GlassToast.show(context, 'Takım banlanamadı. Destek kodu: FM-ONL-006', isError: true);
      }
    } finally {
      if (mounted) setState(() => submittingBan = false);
    }
  }

  List<Pick> get results {
    final q = normalize(search.text),
        chosen = selected.map((pick) => pick.player.id).toSet();
    if (q.isEmpty) {
      return suggestions
          .where((pick) => !chosen.contains(pick.player.id))
          .toList();
    }
    final found =
        candidates
            .where(
              (pick) =>
                  !chosen.contains(pick.player.id) &&
                  [
                    pick.player.name,
                    ...pick.player.aliases,
                    pick.player.team,
                  ].any((text) => normalize(text).contains(q)),
            )
            .toList()
          ..sort((a, b) => a.player.name.compareTo(b.player.name));
    return found.take(40).toList();
  }

  int positionCount(String position) =>
      selected.where((pick) => pick.player.position == position).length;
  void add(Pick pick) {
    if (positionCount(pick.player.position) >=
        formation.quota(pick.player.position)) {
      GlassToast.show(
        context,
        '${positionName(pick.player.position)} kontenjanı dolu.',
        isError: true,
      );
      return;
    }
    gameStore.tap(GameSound.select);
    setState(() => selected.add(pick));
  }

  Future<void> submit() async {
    if (phase != OnlineSquadPhase.selection) return;
    setState(() => phase = OnlineSquadPhase.waiting);
    try {
      if (widget.isRanked) {
        await rankedStore!.repository.submitRankedSquad(
          widget.session.rankedMatchId!,
          selected.map((pick) => {
            'id': pick.player.id,
            'stat': pick.value,
          }).toList(),
          'submit_${widget.session.rankedMatchId}_$mySide',
        );
      } else {
        await widget.repository.submitSquad(
          widget.session,
          selected
              .map(
                (pick) => {
                  'id': pick.player.id,
                  'team_id': pick.player.teamId,
                  'position': pick.player.position,
                },
              )
              .toList(),
        );
      }
      unawaited(
        diagnostics.record(
          level: 'info',
          event: 'online_squad_locked',
          metadata: {'selected_count': selected.length},
          repository: widget.repository,
        ),
      );
      gameStore.tap(GameSound.lock);
    } catch (error) {
      unawaited(
        diagnostics.record(
          level: 'error',
          event: 'online_squad_lock_failed',
          errorCode: 'FM-ONL-007',
          metadata: {
            'kind': error.runtimeType.toString(),
            'msg': error.toString(),
          },
          repository: widget.repository,
        ),
      );
      if (!mounted) return;
      setState(() => phase = OnlineSquadPhase.selection);
      GlassToast.show(
        context,
        'Kadro kilitlenemedi. FM-ONL-007. Hata: ${error.toString()}',
        isError: true,
      );
    }
  }

  Future<void> loadResults() async {
    if (phase == OnlineSquadPhase.result &&
        squads['host']!.isNotEmpty &&
        squads['guest']!.isNotEmpty) {
      return;
    }
    for (var attempt = 0; attempt < 5; attempt++) {
      final raw = await widget.repository.loadSquads(widget.session);
      if (raw.containsKey('host') && raw.containsKey('guest')) {
        if (!mounted) return;
        Pick convert(String id) {
          final player = widget.data.multiLeague!.players[id]!;
          return Pick(player, player.stats[draw.metric] ?? 0);
        }

        setState(() {
          squads = {
            'host': raw['host']!.map(convert).toList(),
            'guest': raw['guest']!.map(convert).toList(),
          };

          if (room.status == OnlineRoomStatus.finished) {
            revealed = [7, 7];
          }

          phase = OnlineSquadPhase.result;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && room.status == OnlineRoomStatus.revealing) reveal();
        });
        return;
      }
      await Future.delayed(const Duration(milliseconds: 450));
    }
  }

  num total(String side) =>
      squads[side]!.fold<num>(0, (sum, pick) => sum + pick.value);
  int? winner() {
    final host = (draw.target - total('host')).abs(),
        guest = (draw.target - total('guest')).abs();
    return host == guest
        ? null
        : host < guest
        ? 0
        : 1;
  }

  String sideName(int side) => side == 0 ? room.host.name : room.guest!.name;

  Widget _playerNameWithAvatar(
    OnlinePlayer player, {
    double fontSize = 12,
    bool bold = true,
  }) {
    String? imagePath;
    if (player.avatarId != null && player.avatarId != 'default') {
      final avatar = GameStore.avatars.firstWhere(
        (a) => a['id'] == player.avatarId,
        orElse: () => <String, dynamic>{},
      );
      if (avatar.isNotEmpty) {
        imagePath = avatar['imagePath'] as String?;
      }
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (imagePath != null) ...[
          ClipOval(child: Image.asset(imagePath, width: fontSize * 1.5, height: fontSize * 1.5, fit: BoxFit.cover)),
          const SizedBox(width: 4),
        ],
        Text(
          player.name,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.w900 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  List<Pick> ordered(String side) {
    final result = <Pick>[];
    for (final position in ['GK', 'DF', 'MF', 'FW']) {
      final found = squads[side]!
          .where((pick) => pick.player.position == position)
          .toList();
      for (var i = 0; i < formation.quota(position); i++) {
        result.add(i < found.length ? found[i] : emptyPick(position));
      }
    }
    return result;
  }

  Future<void> reveal() async {
    if (revealing) return;
    setState(() {
      revealing = true;
      revealed = [0, 0];
    });

    // Sync start with opponent
    if (room.endTime != null) {
      final waitMs = room.endTime!
          .toUtc()
          .difference(widget.repository.serverNow)
          .inMilliseconds;
      if (waitMs > 0) await Future.delayed(Duration(milliseconds: waitMs));
    }
    if (!mounted) return;

    final orderedSides = [ordered('host'), ordered('guest')];
    for (var slot = 0; slot < 7; slot++) {
      if (room.revealFast) break;
      for (var side = 0; side < 2; side++) {
        if (!mounted) return;
        if (room.revealFast) break;
        setState(() {
          spotlight = orderedSides[side][slot];
          spotlightSide = side;
          spotlightValue = false;
        });
        gameStore.tap(GameSound.reveal);
        await Future.delayed(
          Duration(milliseconds: gameStore.animations ? 1000 : 100),
        );
        if (!mounted) return;
        setState(() {
          spotlightValue = true;
          revealed[side] = slot + 1;
        });
        await Future.delayed(
          Duration(milliseconds: gameStore.animations ? 700 : 80),
        );
        if (!mounted) return;
        setState(() => spotlight = null);
      }
    }
    if (room.revealFast && mounted) {
      setState(() {
        revealed = [7, 7];
        spotlight = null;
      });
    }
    if (mounted) {
      final best = min(
        (draw.target - total('host')).abs(),
        (draw.target - total('guest')).abs(),
      );
      best == 0 ? gameStore.perfect() : gameStore.success();
      setState(() => revealing = false);
      if (isLeader && !resultRecorded) {
        resultRecorded = true;
        try {
          if (widget.isRanked) {
            await rankedStore!.repository.finalizeRankedMatch(widget.session.rankedMatchId!);
          } else {
            await widget.repository.finishMatch(
              widget.session,
              total('host'),
              total('guest'),
              draw.target,
            );
          }
          unawaited(
            diagnostics.record(
              level: 'info',
              event: 'online_result_recorded',
              repository: widget.repository,
            ),
          );
        } catch (error) {
          resultRecorded = false;
          unawaited(
            diagnostics.record(
              level: 'error',
              event: 'online_result_save_failed',
              errorCode: 'FM-ONL-009',
              metadata: {'kind': error.runtimeType.toString()},
              repository: widget.repository,
            ),
          );
          if (mounted) {
            GlassToast.show(context, 'Maç geçmişe kaydedilemedi. Destek kodu: FM-ONL-009', isError: true);
          }
        }
      }
    }
  }

  bool _isExiting = false;
  Future<void> exitGame() async {
    if (_isExiting) return;
    _isExiting = true;
    try {
      await widget.repository.leaveRoom(widget.session);
    } catch (_) {}
    await clearActiveOnlineSession();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> startRematch() async {
    if (!isLeader) return;
    try {
      await widget.repository.startSquadMatch(
        widget.session,
        createOnlineMatchSetup(widget.data),
      );
      gameStore.tap(GameSound.refresh);
    } catch (error) {
      if (mounted) {
        GlassToast.show(context, error.toString(), isError: true);
      }
    }
  }

  int remainingForOpponent() {
    final opponentLocked = isLeader ? room.guestLocked : room.hostLocked;
    if (opponentLocked) return 0;
    final endTime = room.endTime;
    if (endTime == null) return 120;
    return max(0, endTime.toUtc().difference(widget.repository.serverNow).inSeconds);
  }

  Future<void> beginReveal() async {
    try {
      await widget.repository.beginReveal(widget.session);
      gameStore.tap(GameSound.start);
    } catch (error) {
      if (mounted) {
        GlassToast.show(context, error.toString(), isError: true);
      }
    }
  }

  Future<void> speedUpReveal() async {
    if (!revealing || room.revealFast || !isLeader) return;
    await widget.repository.speedUpReveal(widget.session);
    gameStore.tap(GameSound.select);
  }

  @override
  void dispose() {
    subscription?.cancel();
    timer?.cancel();
    clockTimer?.cancel();
    reconnectTimer?.cancel();
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OnlinePresenceScope(
    repository: widget.repository,
    session: widget.session,
    child: Stack(
      children: [
        switch (phase) {
          OnlineSquadPhase.draw => DrawCeremony(
            round: draw,
            season: setup['season'] as String,
            onReady: openBanPhase,
            onExit: exitGame,
          ),
          OnlineSquadPhase.banning => buildBan(),
          OnlineSquadPhase.selection => buildSelection(),
          OnlineSquadPhase.waiting => buildWaiting(),
          OnlineSquadPhase.result => buildResult(),
        },
        if (!connectionLost &&
            !opponentConnected &&
            room.guest != null &&
            room.status != OnlineRoomStatus.closed)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 14,
            right: 14,
            child: _OnlineStatusBanner(
              icon: Icons.person_off_rounded,
              text: disconnectWinAvailable
                  ? 'Rakibin bir dakikadır çevrimdışı. Maçı hükmen bitirebilirsin.'
                  : 'Rakibin bağlantısı kesildi. Maç korunuyor ve yeniden bağlanması bekleniyor.',
              color: Color(0xFF5B421D),
              actionLabel: disconnectWinAvailable ? 'HÜKMEN BİTİR' : null,
              onAction: disconnectWinAvailable ? claimDisconnectWin : null,
            ),
          ),
        if (connectionLost)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 14,
            right: 14,
            child: Material(
              color: const Color(0xFF5B2020),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () {
                  setState(() => connectionLost = false);
                  listenRoom();
                },
                borderRadius: BorderRadius.circular(14),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Row(
                    children: [
                      Icon(Icons.wifi_off_rounded, color: Colors.white),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Bağlantı kesildi. Otomatik olarak yeniden bağlanılıyor…',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (room.status == OnlineRoomStatus.closed)
          Positioned.fill(
            child: ColoredBox(
              color: bg,
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: CardBox(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            room.closedBy != widget.session.playerId
                                ? Icons.emoji_events_rounded
                                : Icons.sports_score_rounded,
                            color: room.closedBy != widget.session.playerId
                                ? green
                                : muted,
                            size: 54,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            room.closedBy != null &&
                                    room.closedBy != widget.session.playerId
                                ? 'Rakibin oyundan ayrıldı.\nHükmen kazandın.'
                                : 'Maçtan ayrıldın.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 16),
                          PrimaryButton(
                            label: 'Ana Menüye Dön',
                            icon: Icons.arrow_back_rounded,
                            onPressed: () => Navigator.popUntil(
                              context,
                              (route) => route.isFirst,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget buildBan() {
    final available = draw.teamIds.where(banLeavesValidSquad).toList();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: bg,
        automaticallyImplyLeading: false,
        title: const Text('Takım Banı'),
        actions: [ExitIcon(onPressed: exitGame)],
      ),
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                const SizedBox(height: 18),
                const Icon(
                  Icons.gpp_bad_rounded,
                  color: Color(0xFFFF6B5F),
                  size: 58,
                ),
                const SizedBox(height: 12),
                const Text(
                  'RAKİBİNE BİR TAKIM BANLA',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Seçtiğin takımın futbolcuları rakibinin kadro listesinde görünmeyecek. İki ban da tamamlanınca süre başlayacak.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, height: 1.4),
                ),
                const SizedBox(height: 22),
                ...draw.teamIds.map((teamId) {
                  final index = draw.teamIds.indexOf(teamId),
                      valid = available.contains(teamId),
                      isSelected = myBan == teamId;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: ListTile(
                      enabled: valid && myBan == null && !submittingBan,
                      onTap: () => submitBan(teamId),
                      tileColor: isSelected ? const Color(0x33FF6B5F) : panel,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFFFF6B5F)
                              : Colors.white10,
                        ),
                      ),
                      leading: Icon(
                        isSelected
                            ? Icons.block_rounded
                            : Icons.shield_outlined,
                        color: isSelected
                            ? const Color(0xFFFF6B5F)
                            : valid
                            ? green
                            : muted,
                      ),
                      title: Text(
                        draw.teamNames[index],
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        valid
                            ? 'Rakibin için banla'
                            : 'Kadro kurulabilmesi için bu takım banlanamaz',
                        style: const TextStyle(color: muted, fontSize: 10),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFFFF6B5F),
                            )
                          : null,
                    ),
                  );
                }),
                const Spacer(),
                if (myBan != null)
                  CardBox(
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            bothBansReady
                                ? 'Banlar tamamlandı, kadro ekranı açılıyor…'
                                : 'Banın kilitlendi. Rakibin bekleniyor…',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (available.isEmpty)
                  const CardBox(
                    child: Text(
                      'Bu kurada kadro yapısını bozmadan banlanabilecek takım bulunamadı.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildSelection() => Scaffold(
    appBar: AppBar(
      backgroundColor: bg,
      automaticallyImplyLeading: false,
      title: Text(
        '${mySide == 'host' ? room.host.name : room.guest!.name} kadro kuruyor',
      ),
      actions: [
        RoundPill(text: formatTime(secondsLeft)),
        const SizedBox(width: 5),
        ExitIcon(onPressed: exitGame),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
            child: CardBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          draw.title,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text(
                        'HEDEF ${draw.target}',
                        style: const TextStyle(
                          color: green,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${draw.prompt} Rakibin ${draw.teamNames[draw.teamIds.indexOf(opponentBan!)]} takımını banladı. Kadronu yalnızca ${joinTurkish(allowedTeamNames)} oyuncularından kurabilirsin.',
                    style: const TextStyle(
                      color: muted,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: SquadPitch(
              formation: formation,
              picks: selected,
              height: (MediaQuery.sizeOf(context).width * .72)
                  .clamp(255.0, 310.0)
                  .toDouble(),
              onRemove: (pick) => setState(() => selected.remove(pick)),
              onDrop: add,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: TextField(
              controller: search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Futbolcu veya takım ara…',
                suffixText: '${selected.length}/7',
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: results.length,
              itemBuilder: (_, index) {
                final pick = results[index];
                final full =
                    positionCount(pick.player.position) >=
                    formation.quota(pick.player.position);
                return Card(
                  color: panel,
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.drag_indicator, color: muted),
                    title: Text(
                      pick.player.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${pick.player.team} • ${positionName(pick.player.position)}',
                    ),
                    trailing: Icon(
                      full ? Icons.block : Icons.add_circle,
                      color: full ? muted : green,
                    ),
                    onTap: () => add(pick),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: PrimaryButton(
              label: selected.length == 7
                  ? 'Kadroyu Kilitle'
                  : '${7 - selected.length} futbolcu daha seç',
              icon: Icons.lock,
              onPressed: selected.length == 7 ? submit : null,
            ),
          ),
        ],
      ),
    ),
  );

  Widget buildWaiting() {
    final bothLocked = room.hostLocked && room.guestLocked;
    final opponentSeconds = remainingForOpponent();
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!bothLocked)
                    const SizedBox(
                      width: 54,
                      height: 54,
                      child: CircularProgressIndicator(strokeWidth: 4),
                    )
                  else
                    const Icon(Icons.lock_open_rounded, color: green, size: 58),
                  const SizedBox(height: 24),
                  const Text(
                    'KADRON KİLİTLENDİ',
                    style: TextStyle(
                      color: green,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    bothLocked
                        ? (isLeader
                              ? 'İki kadro da hazır. Açılış sende!'
                              : 'Oda kurucusu kadroları açacak.')
                        : 'Rakibinin kadrosunu tamamlaması bekleniyor.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 13),
                  if (!bothLocked)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: panel,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        'Rakibin kalan süresi  ${formatTime(opponentSeconds)}',
                        style: const TextStyle(
                          color: green,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  const SizedBox(height: 13),
                  Text(
                    '${room.host.name}: ${room.hostLocked ? 'Hazır' : 'Seçiyor'}\n${room.guest!.name}: ${room.guestLocked ? 'Hazır' : 'Seçiyor'}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: muted, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  if (bothLocked && isLeader)
                    PrimaryButton(
                      label: 'Kadroları Aç',
                      icon: Icons.visibility_rounded,
                      onPressed: beginReveal,
                    )
                  else if (bothLocked)
                    const Text(
                      'Açılış komutu bekleniyor…',
                      style: TextStyle(
                        color: muted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: exitGame,
                    icon: const Icon(Icons.exit_to_app),
                    label: const Text('Oyundan Çık'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildResult() {
    final fully = revealed.every((value) => value >= 7), winning = winner();
    final winnerText = winning == null
        ? 'BERABERE'
        : sideName(winning).toUpperCase();
    final perfect =
        (draw.target - total('host')).abs() == 0 ||
        (draw.target - total('guest')).abs() == 0;
    return GestureDetector(
      onTap: speedUpReveal,
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        body: Stack(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
                child: Column(
                  children: [
                    Text(
                      fully ? 'MEYDANIN KAZANANI' : 'KADROLAR AÇIKLANIYOR',
                      style: const TextStyle(
                        color: green,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.7,
                      ),
                    ),
                    Text(
                      fully ? winnerText : 'ONLINE KADRO DÜELLOSU',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: fully ? 35 : 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'HEDEF ${draw.target} ${draw.unit} • ${draw.leagueName}',
                      style: const TextStyle(
                        color: green,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: List.generate(2, (side) {
                        final key = side == 0 ? 'host' : 'guest';
                        final player = side == 0 ? room.host : room.guest!;
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: panel,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: fully && winning == side
                                    ? green
                                    : Colors.white12,
                              ),
                            ),
                            child: Column(
                              children: [
                                _playerNameWithAvatar(player, fontSize: 13),
                                Text(
                                  fully
                                      ? '${total(key)}'
                                      : '${revealed[side]}/7',
                                  style: const TextStyle(
                                    color: green,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Row(
                            children: List.generate(2, (side) {
                              final key = side == 0 ? 'host' : 'guest';
                              final player = side == 0
                                  ? room.host
                                  : room.guest!;
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  child: Column(
                                    children: [
                                      _playerNameWithAvatar(
                                        player,
                                        fontSize: 10,
                                      ),
                                      const SizedBox(height: 4),
                                      Expanded(
                                        child: SquadPitch(
                                          formation: formation,
                                          picks: squads[key]!,
                                          height: null,
                                          revealCount: revealed[side],
                                          showValues: true,
                                          compact: true,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),
                          if (spotlight != null)
                            RevealSpotlight(
                              name: sideName(spotlightSide),
                              pick: spotlight!,
                              unit: draw.unit,
                              showValue: spotlightValue,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (!fully)
                      PrimaryButton(
                        label: room.revealFast
                            ? 'Hızlı Açılış…'
                            : isLeader
                            ? 'Hızlandırmak İçin Ekrana Dokun'
                            : 'Oda Kurucusu Açıklıyor…',
                        icon: Icons.hourglass_bottom,
                        onPressed: null,
                      )
                    else
                      widget.isRanked 
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: PrimaryButton(
                              label: 'Dereceli Sonuçları',
                              icon: Icons.arrow_forward_rounded,
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RankedResultScreen(
                                      session: widget.session,
                                      hostTotal: total('host'),
                                      guestTotal: total('guest'),
                                      target: draw.target,
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: exitGame,
                                  icon: const Icon(Icons.home_rounded),
                                  label: const Text('Ana Menü'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: isLeader ? startRematch : null,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: Text(isLeader ? 'Rövanş' : 'Lideri Bekle'),
                                ),
                              ),
                            ],
                          ),
                  ],
                ),
              ),
            ),
            if (fully && !revealing && gameStore.animations)
              Positioned.fill(
                child: IgnorePointer(
                  child: WinnerCelebration(
                    winnerName: winnerText,
                    draw: winning == null,
                    perfect: perfect,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum OnlineSquadPhase { draw, banning, selection, waiting, result }

class _OnlineStatusBanner extends StatelessWidget {
  const _OnlineStatusBanner({
    required this.icon,
    required this.text,
    required this.color,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(14),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
