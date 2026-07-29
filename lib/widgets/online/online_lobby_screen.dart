import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../utils/helpers.dart';
import '../../online/online_game.dart';
import 'online_squad_screen.dart';
import 'online_profile_screen.dart';
import 'online_presence_scope.dart';

import '../../globals.dart';
import '../../constants.dart';
import '../../models/game_data.dart';
import 'package:futbol_meydani/widgets/common_widgets.dart';
import 'package:futbol_meydani/utils/glass_toast.dart';

class OnlineLobbyScreen extends StatelessWidget {
  OnlineLobbyScreen({
    super.key,
    required this.data,
    required this.repository,
    required this.session,
  }) : roomStream = repository.watchRoom(session.roomCode);
  final GameData data;
  final OnlineGameRepository repository;
  final OnlineSession session;
  final Stream<OnlineRoom?> roomStream;

  void message(BuildContext context, Object value) =>
      GlassToast.show(context, value.toString().replaceFirst('Bad state: ', ''), isError: true);

  Future<void> addTestRival(BuildContext context) async {
    try {
      final rival = await repository.joinRoom(session.roomCode, 'Test Rakibi');
      await repository.setReady(rival, true);
      if (context.mounted) {
        message(context, 'Test rakibi odaya katıldı ve hazır.');
      }
    } catch (value) {
      if (context.mounted) message(context, value);
    }
  }

  Map<String, dynamic> createMatchSetup() => createOnlineMatchSetup(data);

  Future<void> changeReady(BuildContext context, bool value) async {
    try {
      await repository.setReady(session, value);
      unawaited(
        diagnostics.record(
          level: 'info',
          event: 'online_ready_changed',
          metadata: {'ready': value},
          repository: repository,
        ),
      );
    } catch (error) {
      unawaited(
        diagnostics.record(
          level: 'error',
          event: 'online_ready_failed',
          errorCode: 'FM-ONL-004',
          metadata: {
            'kind': error.runtimeType.toString(),
            'msg': error.toString(),
          },
          repository: repository,
        ),
      );
      if (context.mounted) {
        message(
          context,
          'Hazır durumu değiştirilemedi. Destek kodu: FM-ONL-004. Hata: ${error.toString()}',
        );
      }
    }
  }

  Future<void> startMatch(BuildContext context) async {
    try {
      await repository.startSquadMatch(session, createMatchSetup());
      unawaited(
        diagnostics.record(
          level: 'info',
          event: 'online_match_started',
          repository: repository,
        ),
      );
      gameStore.tap(GameSound.start);
    } catch (error) {
      unawaited(
        diagnostics.record(
          level: 'error',
          event: 'online_match_start_failed',
          errorCode: 'FM-ONL-005',
          metadata: {'kind': error.runtimeType.toString()},
          repository: repository,
        ),
      );
      if (context.mounted) {
        message(context, 'Maç başlatılamadı. Destek kodu: FM-ONL-005');
      }
    }
  }

  @override
  Widget build(BuildContext context) => OnlinePresenceScope(
    repository: repository,
    session: session,
    child: PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF150F00),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF00E676), width: 1),
            ),
            title: const Text(
              'Odadan Ayrıl',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: const Text(
              'Odadan ayrılmak istediğinize emin misiniz?',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('İPTAL', style: TextStyle(color: Colors.white54)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'AYRIL',
                  style: TextStyle(color: Color(0xFFFF7777), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
        
        if (shouldLeave == true) {
          await repository.leaveRoom(session);
          await clearActiveOnlineSession();
          if (context.mounted) Navigator.pop(context, result);
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Bekleme Odası'),
          actions: [
            IconButton(
              tooltip: 'Davet Et',
              onPressed: () {
                gameStore.tap(GameSound.select);
                _showInviteBottomSheet(context, session.roomCode);
              },
              icon: const Icon(Icons.person_add_rounded, color: Colors.white),
            ),
          ],
        ),
        body: AppBackground(
          child: SafeArea(
            child: StreamBuilder<OnlineRoom?>(
              stream: roomStream,
              builder: (context, snapshot) {
                final room = snapshot.data;
                if (room == null) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 14),
                        Text(
                          'Odaya yeniden bağlanılıyor…',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  );
                }
                if (room.status == OnlineRoomStatus.closed) {
                  return Center(
                    child: CardBox(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.meeting_room_outlined,
                            color: muted,
                            size: 42,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            room.closedBy != null &&
                                    room.closedBy != session.playerId
                                ? 'Rakibin oyundan ayrıldı.\nHükmen kazandın.'
                                : 'Oda kapatıldı.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          PrimaryButton(
                            label: 'Geri Dön',
                            icon: Icons.arrow_back_rounded,
                            onPressed: () async {
                              await clearActiveOnlineSession();
                              if (context.mounted) Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final me = room.host.id == session.playerId
                    ? room.host
                    : room.guest;
                final isLeader = room.host.id == session.playerId;
                final started =
                    room.status == OnlineRoomStatus.playing ||
                    room.status == OnlineRoomStatus.ready ||
                    room.status == OnlineRoomStatus.revealing ||
                    room.status == OnlineRoomStatus.finished;
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      'ODA KODU',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: green,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 5),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: room.code));
                        gameStore.tap();
                        message(context, 'Oda kodu kopyalandı.');
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              room.code,
                              style: const TextStyle(
                                fontSize: 38,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 9,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.copy_rounded,
                              color: green,
                              size: 19,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 21),
                    ProfilePlayerTile(
                      player: room.host,
                      label: 'ODA KURUCUSU',
                      isMe: room.host.id == session.playerId,
                    ),
                    const SizedBox(height: 9),
                    if (room.guest != null) ...[
                      ProfilePlayerTile(
                        player: room.guest!,
                        label: 'RAKİP',
                        isMe: room.guest!.id == session.playerId,
                      ),

                    ] else
                      Container(
                        height: 82,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 11),
                            Text(
                              'Rakip bekleniyor…',
                              style: TextStyle(
                                color: muted,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 17),
                    if (started)
                      Container(
                        padding: const EdgeInsets.all(19),
                        decoration: BoxDecoration(
                          color: green.withValues(alpha: .13),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: green),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.stadium_rounded,
                              color: green,
                              size: 46,
                            ),
                            const SizedBox(height: 9),
                            const Text(
                              'MEYDAN HAZIR',
                              style: TextStyle(
                                color: green,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'Ortak kura hazırlandı. İki oyuncu kendi telefonunda gizli kadrosunu kurabilir.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 14),
                            PrimaryButton(
                              label: room.status == OnlineRoomStatus.revealing
                                  ? 'Sonuçlara Gir'
                                  : 'Kadro Kurmaya Gir',
                              icon: Icons.arrow_forward_rounded,
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OnlineSquadScreen(
                                    data: data,
                                    repository: repository,
                                    session: session,
                                    initialRoom: room,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      if (!isLeader) ...[
                        Center(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: me?.ready == true ? green : Colors.white,
                              side: BorderSide(color: me?.ready == true ? green : Colors.white38),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            icon: Icon(
                              me?.ready == true ? Icons.check_circle_rounded : Icons.sports_soccer_rounded,
                              size: 18,
                            ),
                            label: Text(
                              me?.ready == true ? 'HAZIRIM (İptal Et)' : 'HAZIR OL',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                            onPressed: me == null ? null : () {
                              gameStore.tap(GameSound.select);
                              changeReady(context, !(me.ready));
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            room.guest?.ready == true
                                ? 'Oda kurucusunun başlatması bekleniyor…'
                                : 'Hazır olman bekleniyor…',
                            style: const TextStyle(
                              color: muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ] else ...[
                        if (room.guest == null && repository is LocalOnlineGameRepository) ...[
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: () => addTestRival(context),
                            icon: const Icon(Icons.science_outlined),
                            label: const Text('Yerel Test Rakibi Ekle'),
                          ),
                        ],
                        const SizedBox(height: 13),
                        PrimaryButton(
                          label: room.guest?.ready == true
                              ? 'Meydan Kadrosunu Başlat'
                              : 'Rakibin Hazır Olması Bekleniyor',
                          icon: Icons.play_arrow_rounded,
                          onPressed: room.guest?.ready == true
                              ? () async {
                                  if (me?.ready != true) {
                                    await changeReady(context, true);
                                  }
                                  if (context.mounted) {
                                    startMatch(context);
                                  }
                                }
                              : null,
                        ),
                      ],
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

  void _showInviteBottomSheet(BuildContext context, String roomCode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _InviteBottomSheetContent(roomCode: roomCode),
    );
  }

class _InviteBottomSheetContent extends StatefulWidget {
  final String roomCode;
  const _InviteBottomSheetContent({required this.roomCode});

  @override
  State<_InviteBottomSheetContent> createState() => _InviteBottomSheetContentState();
}

class _InviteBottomSheetContentState extends State<_InviteBottomSheetContent> {
  int _mode = 0; // 0: menu, 1: qr, 2: friends

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white10),
          ),
          child: SafeArea(
            child: AnimatedSize(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            clipBehavior: Clip.hardEdge,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.topCenter,
                  children: <Widget>[
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                );
              },
              child: _buildContent(),
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildContent() {
    if (_mode == 1) return _buildQrCode();
    if (_mode == 2) return _buildFriends();
    return _buildMenu();
  }

  Widget _buildMenu() {
    return Column(
      key: const ValueKey('menu'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Rakip Davet Et',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        ListTile(
          onTap: () => setState(() => _mode = 2),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people_alt_rounded, color: Colors.white),
          ),
          title: const Text('Arkadaşlarından Seç', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white)),
          subtitle: const Text('Kayıtlı arkadaşlarını odaya çağır', style: TextStyle(color: Colors.white54, fontSize: 13)),
        ),
        const SizedBox(height: 12),
        ListTile(
          onTap: () => setState(() => _mode = 1),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.qr_code_rounded, color: Colors.white),
          ),
          title: const Text('QR Kod Göster', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white)),
          subtitle: const Text('Yanındaki arkadaşına kodu okut', style: TextStyle(color: Colors.white54, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildQrCode() {
    return Column(
      key: const ValueKey('qr'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => setState(() => _mode = 0),
            ),
            const Expanded(
              child: Text(
                'Davet QR Kodu',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: QrImageView(
            data: widget.roomCode,
            version: QrVersions.auto,
            size: 240.0,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Colors.black87,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Arkadaşının cihazından "QR ile Katıl" seçeneğiyle okutmasını iste.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildFriends() {
    return Column(
      key: const ValueKey('friends'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => setState(() => _mode = 0),
            ),
            const Expanded(
              child: Text(
                'Arkadaş Davet Et',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Text(
            'Arkadaş listesi çok yakında burada olacak!',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ),
      ],
    );
  }
}
