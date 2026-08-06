import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../globals.dart';
import '../../constants.dart';
import '../../online/online_game.dart';
import '../widgets/online/online_squad_screen.dart';
import '../widgets/common_widgets.dart';
import '../../models/game_data.dart';
import '../../services/supabase_state.dart';
import '../../services/ranked_league_store.dart';
import '../../online/supabase_online_game.dart';

class RankedMatchmakingScreen extends StatefulWidget {
  final GameData data;
  final String ladderType;
  const RankedMatchmakingScreen({super.key, required this.data, this.ladderType = 'normal'});

  @override
  State<RankedMatchmakingScreen> createState() => _RankedMatchmakingScreenState();
}

class _RankedMatchmakingScreenState extends State<RankedMatchmakingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _spinCtrl;
  Timer? _pollingTimer;
  Timer? _elapsedTimer;
  int _secondsElapsed = 0;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _startSearch();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _secondsElapsed++);
      }
    });
  }

  void _startSearch() async {
    await _pollMatch();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _pollMatch();
    });
  }

  Future<void> _pollMatch() async {
    if (!mounted || rankedStore == null) return;
    try {
      final playerName = gameStore.prefs.getString('player_name') ?? 'Oyuncu';
      final avatarId = gameStore.prefs.getString('currentAvatar');
      
      final session = await rankedStore!.repository.joinRankedQueue(widget.ladderType, playerName, avatarId);
      if (session != null) {
        _onMatchFound(session);
      }
    } catch (_) {}
  }

  void _onMatchFound(OnlineSession session) async {
    _pollingTimer?.cancel();
    _elapsedTimer?.cancel();
    _spinCtrl.stop();
    if (!mounted) return;
    
    final playerName = gameStore.prefs.getString('player_name') ?? 'Oyuncu';
    await saveActiveOnlineSession(session, playerName);
    
    if (!mounted) return;
    final repo = SupabaseOnlineGameRepository(SupabaseState.client!);
    final initialRoom = await repo.loadRoom(session.roomCode);
    if (!mounted) return;
    if (initialRoom != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OnlineSquadScreen(
            data: widget.data,
            repository: repo,
            session: session,
            initialRoom: initialRoom,
            isRanked: true,
          ),
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _cancelSearch() async {
    _pollingTimer?.cancel();
    _elapsedTimer?.cancel();
    _spinCtrl.stop();
    if (rankedStore != null) {
      await rankedStore!.repository.cancelRankedQueue();
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _elapsedTimer?.cancel();
    _spinCtrl.dispose();
    super.dispose();
  }

  String _formatElapsed() {
    final mins = (_secondsElapsed ~/ 60).toString().padLeft(2, '0');
    final secs = (_secondsElapsed % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final league = rankedStore?.currentLeague;
    final leagueName = league?.displayName ?? 'Kırmızı Meydan';
    final leagueColor = league?.color ?? const Color(0xFFFF453A);

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                const SizedBox(height: 12),
                // Top Header Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: leagueColor.withOpacity(0.6), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: leagueColor.withOpacity(0.2),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emoji_events_rounded, color: leagueColor, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        leagueName.toUpperCase(),
                        style: TextStyle(
                          color: leagueColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),

                // Center Lottie Animation with Dim Black Circle & Rotating Neon Radar Arc
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // 1. Static Dim Black Circle Background
                    Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.55),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.12),
                          width: 1.5,
                        ),
                      ),
                    ),
                    // 2. Rotating Subtle Dim White/Silver Arc Border
                    RotationTransition(
                      turns: _spinCtrl,
                      child: Container(
                        width: 224,
                        height: 224,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: [
                              Colors.white.withOpacity(0.38),
                              Colors.white.withOpacity(0.08),
                              Colors.transparent,
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.22, 0.45, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // 3. Lottie Animation
                    SizedBox(
                      width: 190,
                      height: 190,
                      child: Lottie.asset(
                        'assets/online/loading.json',
                        repeat: true,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF00E676),
                              strokeWidth: 3,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 36),

                // Matchmaking Text Info (Box removed, direct crisp typography)
                Column(
                  children: [
                    const Text(
                      'RAKİP ARANIYOR',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2.0,
                        shadows: [
                          Shadow(color: Colors.black, blurRadius: 14),
                          Shadow(color: Colors.black, blurRadius: 6),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF00E676).withOpacity(0.5)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        'SÜRE: ${_formatElapsed()}',
                        style: const TextStyle(
                          color: Color(0xFF00E676),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Dereceli liginize uygun güçte bir rakip eşleştiriliyor.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(color: Colors.black, blurRadius: 10),
                        ],
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Cancel Button
                GestureDetector(
                  onTap: _cancelSearch,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFF453A).withOpacity(0.7), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF453A).withOpacity(0.2),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.close_rounded, color: Color(0xFFFF453A), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'ARAMAYI İPTAL ET',
                          style: TextStyle(
                            color: Color(0xFFFF453A),
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
