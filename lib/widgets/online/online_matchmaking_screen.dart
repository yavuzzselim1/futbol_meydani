import 'dart:async';
import 'package:flutter/material.dart';
import '../../online/online_game.dart';
import 'online_lobby_screen.dart';

import '../../globals.dart';
import '../../constants.dart';
import '../../models/game_data.dart';
import '../../widgets/common_widgets.dart';

class OnlineMatchmakingScreen extends StatefulWidget {
  const OnlineMatchmakingScreen({
    super.key,
    required this.data,
    required this.repository,
    required this.playerName,
  });
  final GameData data;
  final OnlineGameRepository repository;
  final String playerName;
  @override
  State<OnlineMatchmakingScreen> createState() =>
      _OnlineMatchmakingScreenState();
}

class _OnlineMatchmakingScreenState extends State<OnlineMatchmakingScreen> {
  Timer? poller;
  bool polling = false;
  bool matched = false;
  String? errorText;
  int seconds = 0;

  @override
  void initState() {
    super.initState();
    find();
    poller = Timer.periodic(const Duration(seconds: 2), (_) {
      seconds += 2;
      if (mounted) setState(() {});
      find();
    });
  }

  Future<void> find() async {
    if (polling || matched) return;
    polling = true;
    try {
      final session = await widget.repository.findMatch(widget.playerName);
      if (session == null || !mounted) return;
      matched = true;
      poller?.cancel();
      await saveActiveOnlineSession(session, widget.playerName);
      unawaited(
        diagnostics.record(
          level: 'info',
          event: 'matchmaking_matched',
          metadata: {'wait_seconds': seconds},
          repository: widget.repository,
        ),
      );
      if (!mounted) return;
      gameStore.success();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OnlineLobbyScreen(
            data: widget.data,
            repository: widget.repository,
            session: session,
          ),
        ),
      );
    } catch (error) {
      unawaited(
        diagnostics.record(
          level: 'error',
          event: 'matchmaking_failed',
          errorCode: 'FM-ONL-003',
          metadata: {'kind': error.runtimeType.toString()},
          repository: widget.repository,
        ),
      );
      print('=== MATCHMAKING ERROR ===');
      print(error);
      if (mounted) {
        setState(
          () => errorText = 'Rakip arama kesildi. Destek kodu: FM-ONL-003',
        );
      }
    } finally {
      polling = false;
    }
  }

  Future<void> cancel() async {
    poller?.cancel();
    await widget.repository.cancelMatchmaking();
    unawaited(
      diagnostics.record(
        level: 'info',
        event: 'matchmaking_cancelled',
        metadata: {'wait_seconds': seconds},
        repository: widget.repository,
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    poller?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Rakip Aranıyor'),
        leading: IconButton(
          onPressed: cancel,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: CardBox(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 72,
                      height: 72,
                      child: CircularProgressIndicator(
                        strokeWidth: 7,
                        color: green,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'MEYDANA RAKİP ARANIYOR',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: green,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.playerName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '$seconds saniyedir kuyruktasın',
                      style: const TextStyle(
                        color: muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorText!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFF7777),
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    OutlinedButton.icon(
                      onPressed: cancel,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Aramayı İptal Et'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
