import 'package:flutter/material.dart';
import '../globals.dart';
import '../constants.dart';
import '../online/online_game.dart';
import '../models/ranked_league.dart';
import '../services/ranked_league_store.dart';

class RankedResultScreen extends StatefulWidget {
  final OnlineSession session;
  final num hostTotal;
  final num guestTotal;
  final num target;

  const RankedResultScreen({
    super.key,
    required this.session,
    required this.hostTotal,
    required this.guestTotal,
    required this.target,
  });

  @override
  State<RankedResultScreen> createState() => _RankedResultScreenState();
}

class _RankedResultScreenState extends State<RankedResultScreen> with SingleTickerProviderStateMixin {
  TrophyTransaction? _transaction;
  bool _loading = true;
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.elasticOut);
    _loadResult();
  }

  Future<void> _loadResult() async {
    // Biraz bekle (veritabanı tetikleyicisi/finalize tamamlanması için)
    await Future.delayed(const Duration(milliseconds: 1500));
    final season = rankedStore?.activeSeason;
    if (season != null) {
      final history = await rankedStore?.repository.getTrophyHistory(season.id, limit: 1);
      if (history != null && history.isNotEmpty && history.first.matchId == widget.session.rankedMatchId) {
        _transaction = history.first;
      }
    }
    
    // Ladder'ı yenile
    await rankedStore?.refresh();
    
    if (mounted) {
      setState(() => _loading = false);
      _animCtrl.forward();
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hostDiff = (widget.target - widget.hostTotal).abs();
    final guestDiff = (widget.target - widget.guestTotal).abs();
    final isHost = widget.session.isHost;
    
    final myDiff = isHost ? hostDiff : guestDiff;
    final opponentDiff = isHost ? guestDiff : hostDiff;
    
    String resultText;
    Color resultColor;
    if (myDiff < opponentDiff) {
      resultText = 'GALİBİYET';
      resultColor = Colors.greenAccent;
    } else if (myDiff > opponentDiff) {
      resultText = 'MAĞLUBİYET';
      resultColor = Colors.redAccent;
    } else {
      resultText = 'BERABERE';
      resultColor = Colors.orangeAccent;
    }

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [resultColor.withOpacity(0.2), bg],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: _loading
                  ? const CircularProgressIndicator(color: green)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          resultText,
                          style: TextStyle(
                            fontFamily: 'Oswald',
                            fontSize: 48,
                            fontWeight: FontWeight.w700,
                            color: resultColor,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Hedef Farkı: ${myDiff.toStringAsFixed(1)} (Rakip: ${opponentDiff.toStringAsFixed(1)})',
                          style: const TextStyle(fontSize: 18, color: Colors.white70),
                        ),
                        const SizedBox(height: 60),
                        if (_transaction != null)
                          ScaleTransition(
                            scale: _scaleAnim,
                            child: _buildTrophyDelta(),
                          )
                        else
                          const Text('Kupa bilgisi alınamadı.', style: TextStyle(color: Colors.white54)),
                        const SizedBox(height: 80),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: panel,
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          child: const Text('ANA MENÜ', style: TextStyle(fontSize: 18, color: Colors.white)),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrophyDelta() {
    final t = _transaction!;
    final isPositive = t.delta >= 0;
    final color = isPositive ? Colors.greenAccent : Colors.redAccent;
    
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.black45,
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.5), width: 3),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 30,
            spreadRadius: 10,
          )
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.emoji_events, size: 60, color: color),
          const SizedBox(height: 12),
          Text(
            isPositive ? '+${t.delta}' : '${t.delta}',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          if (t.antiFarmFactor < 1.0)
            const Text(
              'Anti-Farm Aktif',
              style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
            ),
        ],
      ),
    );
  }
}
