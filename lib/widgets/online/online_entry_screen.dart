import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'online_lobby_screen.dart';
import 'online_matchmaking_screen.dart';
import 'online_profile_screen.dart';
import 'online_squad_screen.dart';

import '../../screens/league_hub_screen.dart';
import '../../screens/ranked_matchmaking_screen.dart';
import '../../services/ranked_league_store.dart';
import '../../online/online_game.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../globals.dart';
import '../../utils/glass_toast.dart';

import '../../constants.dart';
import '../../models/game_data.dart';
import '../../online/supabase_online_game.dart';
import '../../widgets/common_widgets.dart';

import '../../services/supabase_state.dart';
import '../../services/game_store.dart';

import '../../screens/auth/auth_screen.dart';

class OnlineEntryScreen extends StatefulWidget {
  const OnlineEntryScreen({super.key, required this.data});
  final GameData data;
  @override
  State<OnlineEntryScreen> createState() => _OnlineEntryScreenState();
}

class _OnlineEntryScreenState extends State<OnlineEntryScreen> {
  final roomCode = TextEditingController();
  late final OnlineGameRepository repository = SupabaseState.client != null
      ? SupabaseOnlineGameRepository(SupabaseState.client!)
      : LocalOnlineGameRepository.instance;
  bool busy = false;
  OnlineSession? savedSession;
  String? savedPlayerName;
  OnlineRoom? savedRoom;
  bool checkingRecovery = true;

  Future<OnlineProfile>? _profileFuture;
  Future<List<OnlineMatchRecord>>? _historyFuture;

  @override
  void initState() {
    super.initState();
    if (repository is SupabaseOnlineGameRepository) {
      unawaited(diagnostics.flush(repository));
    }
    unawaited(_recoverOnlineSession());

    if (SupabaseState.client?.auth.currentSession != null) {
      _profileFuture = repository.loadProfile();
      _historyFuture = repository.loadMatchHistory();
    }
  }

  Future<void> _recoverOnlineSession() async {
    if (repository is! SupabaseOnlineGameRepository) {
      if (mounted) setState(() => checkingRecovery = false);
      return;
    }

    try {
      await repository.cleanupStaleRooms();
      final recovered = await repository.recoverActiveSession();
      if (recovered == null) {
        await clearActiveOnlineSession();
        if (mounted) {
          setState(() {
            savedSession = null;
            savedRoom = null;
            checkingRecovery = false;
          });
        }
        return;
      }

      final room = await repository.loadRoom(recovered.roomCode);
      if (room == null ||
          room.status == OnlineRoomStatus.closed ||
          (recovered.isHost && room.guest == null)) {
        await clearActiveOnlineSession();
        if (mounted) setState(() => checkingRecovery = false);
        return;
      }

      final playerName = recovered.isHost
          ? room.host.name
          : room.guest?.name ?? gameStore.playerName;
      await saveActiveOnlineSession(recovered, playerName);
      if (!mounted) return;
      setState(() {
        savedSession = recovered;
        savedRoom = room;
        savedPlayerName = playerName;
        checkingRecovery = false;
      });
    } catch (_) {
      final code = gameStore.prefs.getString('online_room_code');
      final id = gameStore.prefs.getString('online_player_id');
      final currentUserId = SupabaseState.client?.auth.currentUser?.id;
      if (!mounted) return;
      setState(() {
        if (code != null && id != null && id == currentUserId) {
          savedSession = OnlineSession(
            roomCode: code,
            playerId: id,
            isHost: gameStore.prefs.getBool('online_is_host') ?? false,
          );
          savedPlayerName = gameStore.prefs.getString('online_player_name');
        } else {
          savedSession = null;
          savedRoom = null;
        }
        checkingRecovery = false;
      });
    }
  }

  Future<void> _restorePresence(OnlineSession session) async {
    try {
      await repository.setPresence(session, true);
    } catch (_) {
      // Lobi/maç ekranındaki heartbeat bağlantıyı yeniden deneyecek.
    }
  }

  Future<void> _continueSavedMatch() async {
    final storedSession = savedSession;
    if (storedSession == null || busy) return;
    setState(() => busy = true);
    try {
      var session = storedSession;
      var room = savedRoom;

      try {
        final recovered = await repository.recoverActiveSession();
        if (recovered != null) {
          session = recovered;
          room = await repository.loadRoom(recovered.roomCode) ?? room;
        }
      } catch (_) {
        // A previously loaded room can still be opened while presence retries.
      }

      room ??= await repository.loadRoom(session.roomCode);
      if (room == null || room.status == OnlineRoomStatus.closed) {
        await clearActiveOnlineSession();
        if (mounted) {
          setState(() {
            savedSession = null;
            savedRoom = null;
          });
          error('Bu oda artık aktif değil.');
        }
        return;
      }
      final activeRoom = room;

      await saveActiveOnlineSession(
        session,
        savedPlayerName ?? gameStore.playerName,
      );
      unawaited(_restorePresence(session));
      if (!mounted) return;
      final inMatch =
          activeRoom.gameSetup != null &&
          {
            OnlineRoomStatus.playing,
            OnlineRoomStatus.ready,
            OnlineRoomStatus.revealing,
            OnlineRoomStatus.finished,
          }.contains(activeRoom.status);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => inMatch
              ? OnlineSquadScreen(
                  data: widget.data,
                  repository: repository,
                  session: session,
                  initialRoom: activeRoom,
                )
              : OnlineLobbyScreen(
                  data: widget.data,
                  repository: repository,
                  session: session,
                ),
        ),
      );
    } catch (value) {
      unawaited(
        diagnostics.record(
          level: 'error',
          event: 'online_room_resume_failed',
          errorCode: 'FM-ONL-008',
          metadata: {
            'kind': value.runtimeType.toString(),
            'msg': value.toString(),
          },
          repository: repository,
        ),
      );
      if (mounted) {
        error(
          'Odaya yeniden bağlanılamadı. Destek kodu: FM-ONL-008. '
          'Hata: $value',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    roomCode.dispose();
    super.dispose();
  }

  void error(Object value) {
    GlassToast.show(
      context,
      value.toString().replaceFirst('Bad state: ', ''),
      isError: true,
    );
  }

  bool _requireOnlineSession() {
    final session = SupabaseState.client?.auth.currentSession;

    if (session != null) return true;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Çevrimiçi giriş gerekli'),
        content: const Text(
          'Oda kurmak, odaya katılmak veya rastgele rakip bulmak için hesabına giriş yapmalısın.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('VAZGEÇ'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AuthScreen()),
              );
            },
            icon: const Icon(Icons.login_rounded),
            label: const Text('GİRİŞ YAP'),
          ),
        ],
      ),
    );

    return false;
  }

  Future<void> createRoom() async {
    if (!_requireOnlineSession()) return;
    if (busy) return;

    if (gameStore.playerName.trim().isEmpty) {
      error('Önce profilinden bir oyuncu adı belirle.');
      return;
    }
    setState(() => busy = true);
    try {
      final session = await repository.createRoom(gameStore.playerName);
      await saveActiveOnlineSession(session, gameStore.playerName);
      unawaited(
        diagnostics.record(
          level: 'info',
          event: 'online_room_created',
          metadata: const {'mode': 'private'},
          repository: repository,
        ),
      );
      if (!mounted) return;
      gameStore.tap(GameSound.start);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OnlineLobbyScreen(
            data: widget.data,
            repository: repository,
            session: session,
          ),
        ),
      );
    } catch (value) {
      unawaited(
        diagnostics.record(
          level: 'error',
          event: 'online_room_create_failed',
          errorCode: 'FM-ONL-001',
          metadata: {'kind': value.runtimeType.toString()},
          repository: repository,
        ),
      );
      if (mounted) error('Oda kurulamadı. Destek kodu: FM-ONL-001');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> joinRoom() async {
    if (!_requireOnlineSession()) return;
    if (gameStore.playerName.isEmpty || roomCode.text.length != 6 || busy) {
      error('Oyuncu adını ve 6 haneli oda kodunu kontrol et.');
      return;
    }
    setState(() => busy = true);
    try {
      final session = await repository.joinRoom(
        roomCode.text,
        gameStore.playerName,
      );
      await saveActiveOnlineSession(session, gameStore.playerName);
      unawaited(
        diagnostics.record(
          level: 'info',
          event: 'online_room_joined',
          metadata: const {'mode': 'code'},
          repository: repository,
        ),
      );
      if (!mounted) return;
      gameStore.tap(GameSound.start);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OnlineLobbyScreen(
            data: widget.data,
            repository: repository,
            session: session,
          ),
        ),
      );
    } catch (value) {
      unawaited(
        diagnostics.record(
          level: 'error',
          event: 'online_room_join_failed',
          errorCode: 'FM-ONL-002',
          metadata: {'kind': value.runtimeType.toString()},
          repository: repository,
        ),
      );
      if (mounted) error('Odaya katılınamadı. Destek kodu: FM-ONL-002');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _startRankedMatchmaking() {
    if (!_requireOnlineSession()) return;
    if (gameStore.playerName.isEmpty) {
      error('Önce oyuncu adını yaz.');
      return;
    }
    gameStore.tap(GameSound.start);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RankedMatchmakingScreen(data: widget.data, ladderType: 'normal'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        resizeToAvoidBottomInset: true,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          centerTitle: true,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'ONLINE MEYDAN',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 2,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white70,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (repository is SupabaseOnlineGameRepository)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OnlineProfileScreen(repository: repository),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.person_rounded,
                          color: Color(0xFF00E676),
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          gameStore.playerName.isEmpty ? 'Profil' : gameStore.playerName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: AppBackground(
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'RAKİPLERİNİ SAHADA DEVİR',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Dünyanın her yerinden gerçek oyuncularla mücadele et',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 20),

                  if (checkingRecovery) ...[
                    const ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                      child: LinearProgressIndicator(
                        color: Color(0xFF00E676),
                        backgroundColor: Colors.white12,
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Saved Active Session Recovery Card
                  if (savedSession != null) ...[
                    _buildRecoveryCard(),
                    const SizedBox(height: 16),
                  ],

                  // Hero Action: Hızlı Eşleşme (Ranked League)
                  _buildPrimaryHeroCard(),
                  const SizedBox(height: 14),

                  // Secondary Actions: Oda Kur & Katıl
                  Row(
                    children: [
                      Expanded(
                        child: _buildSecondaryCard(
                          title: 'Oda Kur',
                          subtitle: 'Arkadaşınla Oyna',
                          badge: 'ÖZEL MAÇ',
                          icon: Icons.add_circle_rounded,
                          accentColor: const Color(0xFF5EC8FF),
                          bgColor: const Color(0xFF0F2B46),
                          onTap: busy ? null : createRoom,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSecondaryCard(
                          title: 'Odaya Katıl',
                          subtitle: 'Kod / QR Okut',
                          badge: 'ÖZEL MAÇ',
                          icon: Icons.qr_code_scanner_rounded,
                          accentColor: const Color(0xFFFF9F0A),
                          bgColor: const Color(0xFF38230D),
                          onTap: busy ? null : () => _showJoinModal(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Dashboard Hub: Leaderboard & Stats
                  const Text(
                    'SEZON & İSTATİSTİKLER',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Split Section: Leaderboard + (Profile & Match History)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 600;
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildLeagueCard()),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                children: [
                                  _buildProfileCard(),
                                  const SizedBox(height: 14),
                                  _buildMatchHistoryCard(),
                                ],
                              ),
                            ),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          _buildProfileCard(),
                          const SizedBox(height: 14),
                          _buildLeagueCard(),
                          const SizedBox(height: 14),
                          _buildMatchHistoryCard(),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _buildRecoveryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF453A).withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFF453A).withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF453A).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.restore_rounded, color: Color(0xFFFF453A), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  savedRoom?.gameSetup == null ? 'Yeniden Bağlan' : 'Maça Devam Et',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${savedPlayerName ?? 'Oyuncu'} ile olan aktif odaya dön.',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: busy ? null : _continueSavedMatch,
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFFF453A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('GİR', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
            onPressed: busy
                ? null
                : () async {
                    setState(() => busy = true);
                    try {
                      final active = await repository.recoverActiveSession();
                      if (active != null) {
                        await repository.leaveRoom(active);
                      } else if (savedSession != null) {
                        await repository.leaveRoom(savedSession!);
                      }
                    } catch (_) {}
                    await clearActiveOnlineSession();
                    if (mounted) {
                      setState(() {
                        savedSession = null;
                        savedPlayerName = null;
                        busy = false;
                      });
                    }
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryHeroCard() {
    return AnimatedOpacity(
      opacity: busy ? 0.6 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: _PressScaleButton(
        onTap: busy ? null : _startRankedMatchmaking,
        child: Image.asset(
          'assets/online/hizli_eslesme.png',
          width: double.infinity,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildSecondaryCard({
    required String title,
    required String subtitle,
    required String badge,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: accentColor.withOpacity(0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accentColor, size: 22),
                  ),
                  Text(
                    badge,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeagueCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ListenableBuilder(
        listenable: rankedStore ?? ChangeNotifier(),
        builder: (context, _) {
          final league = rankedStore?.currentLeague;
          final leagueId = league?.id ?? 'kirmizi';
          final leagueName = league?.displayName ?? 'Kırmızı Meydan';
          final leagueColor = league?.color ?? const Color(0xFFFF453A);
          final seasonId = rankedStore?.activeSeason?.id;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.emoji_events_rounded, color: leagueColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        leagueName.toUpperCase(),
                        style: TextStyle(
                          color: leagueColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LeagueHubScreen(data: widget.data),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Text(
                          'Ligler',
                          style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(width: 2),
                        Icon(Icons.chevron_right_rounded, color: Colors.white60, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 12),

              if (seasonId == null)
                Container(
                  height: 140,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.hourglass_empty_rounded, color: Colors.white30, size: 28),
                      SizedBox(height: 8),
                      Text(
                        'Sezon Bekleniyor',
                        style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  height: 240,
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: rankedStore!.repository.getLeaderboard(seasonId, leagueId, 'normal', limit: 20),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFD700)));
                      }
                      final list = snapshot.data ?? [];

                      return ListView.builder(
                        padding: EdgeInsets.zero,
                        physics: const BouncingScrollPhysics(),
                        itemCount: 20,
                        itemBuilder: (context, index) {
                          final row = index < list.length ? list[index] : null;
                          final hasPlayer = row != null;
                          final name = row?['name'] ?? '';
                          final trophies = row != null ? row['trophies'].toString() : '';
                          final isMe = row != null && row['user_id'] == SupabaseState.client?.auth.currentUser?.id;

                          final isFirst = index == 0;
                          final isSecond = index == 1;
                          final isThird = index == 2;
                          final rankColor = isFirst
                              ? const Color(0xFFFFD700)
                              : isSecond
                                  ? const Color(0xFFC0C0C0)
                                  : isThird
                                      ? const Color(0xFFCD7F32)
                                      : Colors.white38;

                          return Container(
                            height: 38,
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? const Color(0xFF00E676).withOpacity(0.12)
                                  : (index % 2 == 0 ? Colors.white.withOpacity(0.03) : Colors.transparent),
                              borderRadius: BorderRadius.circular(8),
                              border: isMe ? Border.all(color: const Color(0xFF00E676).withOpacity(0.4)) : null,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: rankColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: hasPlayer
                                      ? Text(
                                          name,
                                          style: TextStyle(
                                            color: isMe ? const Color(0xFF00E676) : Colors.white,
                                            fontSize: 13,
                                            fontWeight: isMe ? FontWeight.w900 : FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        )
                                      : Text(
                                          '· · · · · · · · · · · ·',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.12),
                                            fontSize: 13,
                                          ),
                                        ),
                                ),
                                if (hasPlayer)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        trophies,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 14),
                                    ],
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileCard() {
    final avatarData = GameStore.avatars.firstWhere(
      (a) => a['id'] == gameStore.currentAvatar,
      orElse: () => GameStore.avatars.first,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: _profileFuture == null
          ? const SizedBox(
              height: 80,
              child: Center(
                child: Text(
                  'Giriş Yapılmadı',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
            )
          : FutureBuilder<OnlineProfile>(
              future: _profileFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 80,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E676))),
                  );
                }
                final profile = snapshot.data;
                if (profile == null) return const SizedBox();
                final winRate = profile.matches > 0 ? (profile.wins / profile.matches * 100).round() : 0;

                return Row(
                  children: [
                    // Avatar Thumbnail
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF00E676), width: 2),
                        image: DecorationImage(
                          image: AssetImage(avatarData['imagePath']),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${profile.matches} Maç • %$winRate Kazanma',
                            style: const TextStyle(color: Color(0xFF00E676), fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _statChip('G', profile.wins, const Color(0xFF00E676)),
                              const SizedBox(width: 8),
                              _statChip('B', profile.draws, const Color(0xFFFFD166)),
                              const SizedBox(width: 8),
                              _statChip('M', profile.losses, const Color(0xFFFF453A)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _statChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildMatchHistoryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: _historyFuture == null
          ? const SizedBox(
              height: 60,
              child: Center(
                child: Text(
                  'Giriş Yapılmadı',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            )
          : FutureBuilder<List<OnlineMatchRecord>>(
              future: _historyFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 60,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E676))),
                  );
                }
                final history = snapshot.data ?? [];
                if (history.isEmpty) {
                  return const SizedBox(
                    height: 60,
                    child: Center(
                      child: Text(
                        'Henüz maç geçmişiniz yok',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'SON MAÇLAR',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OnlineProfileScreen(repository: repository),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Text(
                                'Tümü',
                                style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                              SizedBox(width: 2),
                              Icon(Icons.chevron_right_rounded, color: Colors.white60, size: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Column(
                      children: history.take(3).map((match) {
                        final won = match.result == 'Galibiyet';
                        final draw = match.result == 'Berabere';
                        final color = won
                            ? const Color(0xFF00E676)
                            : draw
                                ? const Color(0xFFFFD166)
                                : const Color(0xFFFF453A);
                        final label = won ? 'GALİBİYET' : draw ? 'BERABERE' : 'MAĞLUBİYET';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  match.opponent,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
            ),
    );
  }

  void _showJoinModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _JoinModalContent(
        roomCodeController: roomCode,
        busy: busy,
        onJoin: joinRoom,
      ),
    );
  }
}

class _JoinModalContent extends StatefulWidget {
  final TextEditingController roomCodeController;
  final bool busy;
  final VoidCallback onJoin;

  const _JoinModalContent({
    required this.roomCodeController,
    required this.busy,
    required this.onJoin,
  });

  @override
  State<_JoinModalContent> createState() => _JoinModalContentState();
}

class _JoinModalContentState extends State<_JoinModalContent> {
  bool _isCameraActive = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.qr_code_scanner_rounded,
                color: Color(0xFF5EC8FF),
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Davet Kodu Gir',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              AnimatedSize(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topCenter,
                clipBehavior: Clip.hardEdge,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  layoutBuilder:
                      (Widget? currentChild, List<Widget> previousChildren) {
                        return Stack(
                          alignment: Alignment.topCenter,
                          children: <Widget>[
                            ...previousChildren,
                            if (currentChild != null) currentChild,
                          ],
                        );
                      },
                  child: _isCameraActive
                      ? KeyedSubtree(
                          key: const ValueKey('scanner'),
                          child: _buildScanner(),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('manual'),
                          child: _buildManualEntry(),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              if (!_isCameraActive)
                PremiumButton(
                  label: widget.busy ? 'Bağlanıyor…' : 'Odaya Katıl',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: widget.busy
                      ? null
                      : () {
                          Navigator.pop(context);
                          widget.onJoin();
                        },
                ),
              if (_isCameraActive)
                PremiumButton(
                  label: 'Kodu Elle Gir',
                  icon: Icons.keyboard_rounded,
                  onPressed: () {
                    setState(() => _isCameraActive = false);
                  },
                ),
              if (!_isCameraActive) ...[
                const SizedBox(height: 12),
                PremiumButton(
                  label: 'Kamerayı Aç (QR Okut)',
                  icon: Icons.camera_alt_rounded,
                  onPressed: () {
                    setState(() => _isCameraActive = true);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManualEntry() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: widget.roomCodeController,
          maxLength: 6,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 12,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            counterText: '',
            hintText: '123456',
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.2),
              letterSpacing: 12,
            ),
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF00E676), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Veya kameranızı kullanarak hızlıca katılın',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildScanner() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 260,
          width: 260,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: MobileScanner(
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  final code = barcode.rawValue;
                  if (code != null &&
                      code.length == 6 &&
                      int.tryParse(code) != null) {
                    widget.roomCodeController.text = code;
                    Navigator.pop(context);
                    widget.onJoin();
                    break;
                  }
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Kamerayı koda doğru tutun',
          style: TextStyle(color: Colors.white70, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _PressScaleButton extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;

  const _PressScaleButton({required this.onTap, required this.child});

  @override
  State<_PressScaleButton> createState() => _PressScaleButtonState();
}

class _PressScaleButtonState extends State<_PressScaleButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(begin: 1.04, end: 1.12).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleTap() async {
    if (widget.onTap == null) return;
    await _ctrl.forward();
    await _ctrl.reverse();
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => widget.onTap != null ? _ctrl.forward() : null,
      onTapUp: (_) => widget.onTap != null ? _ctrl.reverse() : null,
      onTapCancel: () => widget.onTap != null ? _ctrl.reverse() : null,
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}
