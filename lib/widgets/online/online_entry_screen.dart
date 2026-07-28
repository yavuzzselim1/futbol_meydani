import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'online_lobby_screen.dart';
import 'online_matchmaking_screen.dart';
import 'online_profile_screen.dart';
import 'online_squad_screen.dart';

import '../../online/online_game.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
    resizeToAvoidBottomInset: true,
    appBar: AppBar(
      title: const Text(
        'Online Meydan',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    extendBodyBehindAppBar: true,
    body: AppBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Dünyanın her yerinden rakiplerle karşılaş veya arkadaşlarınla özel maç yap.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (repository is SupabaseOnlineGameRepository)
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OnlineProfileScreen(repository: repository),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Icon(Icons.person_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                ],
              ),
              const Spacer(),

              if (checkingRecovery) ...[
                const LinearProgressIndicator(color: Color(0xFF5EC8FF), backgroundColor: Colors.white24),
                const SizedBox(height: 16),
              ],
              
              if (savedSession != null) ...[
                _buildActionCard(
                  title: savedRoom?.gameSetup == null ? 'Yeniden Bağlan' : 'Maça Devam Et',
                  subtitle: '${savedPlayerName ?? 'Oyuncu'} ile olan odaya geri dön.',
                  icon: Icons.restore_rounded,
                  color: const Color(0xFFFF453A),
                  onTap: busy ? null : _continueSavedMatch,
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: busy ? null : () async {
                      setState(() => busy = true);
                      try {
                        final active = await repository.recoverActiveSession();
                        if (active != null) await repository.leaveRoom(active);
                        else if (savedSession != null) await repository.leaveRoom(savedSession!);
                      } catch (_) {}
                      await clearActiveOnlineSession();
                      if (mounted) setState(() { savedSession = null; savedPlayerName = null; busy = false; });
                    },
                    child: const Text('Kaydı Sil', style: TextStyle(color: Colors.white54)),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              _buildActionCard(
                title: 'Hızlı Eşleşme',
                subtitle: 'Rastgele bir rakip bul',
                icon: Icons.bolt_rounded,
                color: const Color(0xFF00E676),
                isPrimary: true,
                onTap: busy ? null : findRandomOpponent,
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      title: 'Oda Kur',
                      subtitle: 'Özel maç',
                      icon: Icons.add_rounded,
                      color: const Color(0xFF5EC8FF),
                      onTap: busy ? null : createRoom,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionCard(
                      title: 'Katıl',
                      subtitle: 'Kod veya QR',
                      icon: Icons.qr_code_scanner_rounded,
                      color: const Color(0xFFFF9F0A),
                      onTap: busy ? null : () => _showJoinModal(context),
                    ),
                  ),
                ],
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: isPrimary ? 36 : 32),
                Icon(Icons.arrow_forward_rounded, color: Colors.white38, size: 24),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: isPrimary ? 24 : 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
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
          height: 220,
          width: double.infinity,
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
