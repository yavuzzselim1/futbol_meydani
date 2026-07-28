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
        appBar: AppBar(
          title: const Text('Bekleme Odası'),
          actions: [
            IconButton(
              tooltip: 'Odadan ayrıl',
              onPressed: () async {
                await repository.leaveRoom(session);
                await clearActiveOnlineSession();
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.logout_rounded, color: Color(0xFFFF7777)),
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
                          color: panel,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0x5571F39A)),
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
                    if (isLeader) ...[
                      const SizedBox(height: 20),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: QrImageView(
                            data: room.code,
                            version: QrVersions.auto,
                            size: 180.0,
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
                      ),
                    ],
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
                      if (!(isLeader
                          ? room.guest!.connected
                          : room.host.connected)) ...[
                        const SizedBox(height: 9),
                        const _OpponentConnectionNotice(),
                      ],
                    ] else
                      Container(
                        height: 82,
                        decoration: BoxDecoration(
                          color: panel.withValues(alpha: .55),
                          borderRadius: BorderRadius.circular(18),
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
                      SwitchListTile(
                        value: me?.ready ?? false,
                        onChanged: me == null
                            ? null
                            : (value) {
                                gameStore.tap(GameSound.select);
                                changeReady(context, value);
                              },
                        tileColor: panel,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                        secondary: Icon(
                          me?.ready == true
                              ? Icons.check_circle_rounded
                              : Icons.hourglass_bottom_rounded,
                          color: me?.ready == true ? green : muted,
                        ),
                        title: Text(
                          me?.ready == true
                              ? 'Hazırsın'
                              : 'Hazır olduğunu bildir',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: const Text(
                          'Kadro düellosu iki oyuncu da hazır olunca başlayabilir.',
                          style: TextStyle(color: muted, fontSize: 10),
                        ),
                      ),
                      if (isLeader &&
                          room.guest == null &&
                          repository is LocalOnlineGameRepository) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => addTestRival(context),
                          icon: const Icon(Icons.science_outlined),
                          label: const Text('Yerel Test Rakibi Ekle'),
                        ),
                      ],
                      const SizedBox(height: 13),
                      if (isLeader)
                        PrimaryButton(
                          label: room.bothPlayersReady
                              ? 'Meydan Kadrosunu Başlat'
                              : 'İki Oyuncu Hazır Olmalı',
                          icon: Icons.play_arrow_rounded,
                          onPressed: room.bothPlayersReady
                              ? () => startMatch(context)
                              : null,
                        )
                      else
                        Center(
                          child: Text(
                            room.bothPlayersReady
                                ? 'Oda kurucusunun başlatması bekleniyor…'
                                : 'İki oyuncunun hazır olması bekleniyor…',
                            style: const TextStyle(
                              color: muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
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

class _OpponentConnectionNotice extends StatelessWidget {
  const _OpponentConnectionNotice();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF5B421D),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFFFC85E)),
    ),
    child: const Row(
      children: [
        Icon(Icons.wifi_off_rounded, color: Color(0xFFFFC85E)),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'Rakibin bağlantısı kesildi. Odayı koruyoruz; yeniden bağlanması bekleniyor.',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}
