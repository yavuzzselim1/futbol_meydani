import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'online_lobby_screen.dart';
import 'online_matchmaking_screen.dart';
import 'online_profile_screen.dart';
import 'online_squad_screen.dart';

import '../../online/online_game.dart';

import '../../globals.dart';
import '../../utils/glass_toast.dart';

import '../../constants.dart';
import '../../models/game_data.dart';
import '../../online/supabase_online_game.dart';
import '../../widgets/common_widgets.dart';

import '../../services/supabase_state.dart';

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

  @override
  void initState() {
    super.initState();
    if (repository is SupabaseOnlineGameRepository) {
      unawaited(diagnostics.flush(repository));
    }
    unawaited(_recoverOnlineSession());
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
      if (room == null || room.status == OnlineRoomStatus.closed) {
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
    GlassToast.show(context, value.toString().replaceFirst('Bad state: ', ''), isError: true);
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

  void findRandomOpponent() {
    if (!_requireOnlineSession()) return;
    if (gameStore.playerName.isEmpty) {
      error('Önce oyuncu adını yaz.');
      return;
    }
    if (repository is! SupabaseOnlineGameRepository) {
      error('Rastgele eşleşme için çevrimiçi bağlantı gerekli.');
      return;
    }
    gameStore.tap(GameSound.start);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OnlineMatchmakingScreen(
          data: widget.data,
          repository: repository,
          playerName: gameStore.playerName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Online Meydan')),
    body: AppBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0x225EC8FF),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x665EC8FF)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    repository is SupabaseOnlineGameRepository
                        ? Icons.cloud_done_rounded
                        : Icons.science_outlined,
                    color: const Color(0xFF5EC8FF),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      repository is SupabaseOnlineGameRepository
                          ? 'ÇEVRİMİÇİ BAĞLANTI\nSupabase etkin. İki farklı cihaz aynı 6 haneli oda koduyla bağlanabilir.'
                          : 'YEREL TEST MODU\nSupabase bilgileri eklenmediği için oda akışı bu cihazda simüle ediliyor.',
                      style: const TextStyle(
                        color: muted,
                        fontSize: 11,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            if (checkingRecovery) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 13),
            ],
            if (savedSession != null) ...[
              CardBox(
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.restore_rounded, color: green),
                        SizedBox(width: 9),
                        Text(
                          'Devam eden oda',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${savedPlayerName ?? 'Oyuncu'} • Oda ${savedSession!.roomCode}',
                      style: const TextStyle(color: muted),
                    ),
                    const SizedBox(height: 13),
                    PrimaryButton(
                      label: savedRoom?.gameSetup == null
                          ? 'Odaya Yeniden Bağlan'
                          : 'Maça Devam Et',
                      icon: Icons.wifi_rounded,
                      onPressed: busy ? null : _continueSavedMatch,
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () async {
                              setState(() => busy = true);
                              try {
                                final active =
                                    await repository.recoverActiveSession();
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
                      child: const Text('Kaydı Unut'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 13),
            ],
            const Text(
              'Meydana nasıl gireceksin?',
              style: TextStyle(
                fontSize: 30,
                height: 1.05,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Oda kur veya arkadaşının verdiği 6 haneli kodu kullan.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 22),
            PrimaryButton(
              label: 'Rastgele Rakip Bul',
              icon: Icons.bolt_rounded,
              onPressed: busy ? null : findRandomOpponent,
            ),
            const SizedBox(height: 7),
            OutlinedButton.icon(
              onPressed: repository is SupabaseOnlineGameRepository
                  ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            OnlineProfileScreen(repository: repository),
                      ),
                    )
                  : null,
              icon: const Icon(Icons.military_tech_rounded),
              label: const Text('Online Profilim ve Maç Geçmişi'),
            ),
            const SizedBox(height: 13),
            CardBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.add_circle_outline_rounded, color: green),
                      SizedBox(width: 9),
                      Text(
                        'Yeni oda kur',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Oda kodunu arkadaşına gönder ve bekleme odasında hazır olun.',
                    style: TextStyle(color: muted, fontSize: 11),
                  ),
                  const SizedBox(height: 14),
                  PrimaryButton(
                    label: busy ? 'Hazırlanıyor…' : 'Oda Kur',
                    icon: Icons.meeting_room_rounded,
                    onPressed: busy ? null : createRoom,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 13),
            CardBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.login_rounded, color: Color(0xFF5EC8FF)),
                      SizedBox(width: 9),
                      Text(
                        'Kodla katıl',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: roomCode,
                    maxLength: 6,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 5,
                    ),
                    decoration: const InputDecoration(
                      labelText: '6 haneli oda kodu',
                      prefixIcon: Icon(Icons.tag_rounded),
                    ),
                  ),
                  const SizedBox(height: 6),
                  PrimaryButton(
                    label: busy ? 'Bağlanıyor…' : 'Odaya Katıl',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: busy ? null : joinRoom,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
