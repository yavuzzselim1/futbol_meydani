import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:futbol_meydani/globals.dart';
import 'package:futbol_meydani/services/game_store.dart';
import 'package:futbol_meydani/utils/glass_toast.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: gameStore,
    builder: (_, _) {
      final leaders = gameStore.wins.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final totalWins = gameStore.wins.values.fold(0, (a, b) => a + b);
      final winRate = gameStore.matches > 0 ? (totalWins / gameStore.matches) * 100 : 0.0;
      
      final title = gameStore.matches >= 20 ? 'Meydan Efsanesi'
          : gameStore.matches >= 8 ? 'Kadro Ustası'
          : gameStore.dailyCompleted >= 3 ? 'Görev Avcısı'
          : 'Yeni Rakip';

      final avatarData = GameStore.avatars.firstWhere((a) => a['id'] == gameStore.currentAvatar, orElse: () => GameStore.avatars.first);
      final String avatarImage = avatarData['imagePath'] as String;
      final Color avatarColor = avatarData['color'] as Color;

      return Scaffold(
        backgroundColor: const Color(0xFF050505),
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          title: const Text('Profilim', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          iconTheme: const IconThemeData(color: Colors.white),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            // Ambient Background Glow
            Positioned(
              top: -100,
              left: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: avatarColor.withValues(alpha: 0.15),
                ),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 100 + MediaQuery.of(context).padding.top, 16, 40 + MediaQuery.of(context).padding.bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- HERO AVATAR AREA ---
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        ClipOval(
                          child: Image.asset(avatarImage, width: 120, height: 120, fit: BoxFit.cover),
                        ),
                        // Level Badge
                        Positioned(
                          bottom: -10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: avatarColor,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(color: avatarColor.withValues(alpha: 0.5), blurRadius: 12, offset: const Offset(0, 4)),
                              ]
                            ),
                            child: Text(
                              'LVL ${gameStore.level}',
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Name and Title
                  Text(
                    gameStore.playerName.isNotEmpty ? gameStore.playerName : 'İsimsiz Oyuncu',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: avatarColor, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 3),
                  ),
                  const SizedBox(height: 36),

                  // --- BENTO BOX STATS ---
                  Row(
                    children: [
                      Expanded(
                        child: _BentoCard(
                          title: 'GALİBİYET',
                          value: '$totalWins',
                          subtitle: '${gameStore.matches} Maç',
                          icon: Icons.emoji_events_rounded,
                          color: const Color(0xFFFFD166),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BentoCard(
                          title: 'BAŞARI ORANI',
                          value: '%${winRate.toStringAsFixed(0)}',
                          subtitle: 'Kazanma',
                          icon: Icons.pie_chart_rounded,
                          color: const Color(0xFF00E676),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Wide card for XP & Friend Code
                  _GlassContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('XP İlerlemesi', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                            Text('${gameStore.xpInLevel} / ${GameStore.xpPerLevel}', style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: gameStore.xpInLevel / GameStore.xpPerLevel,
                            backgroundColor: Colors.black.withValues(alpha: 0.3),
                            color: avatarColor,
                            minHeight: 12,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text('ARKADAŞ KODU', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: gameStore.friendCode));
                            GlassToast.show(context, 'Arkadaş kodu kopyalandı!', isError: false);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  gameStore.friendCode,
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 4),
                                ),
                                const Icon(Icons.copy_rounded, color: Colors.white54, size: 22),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _BentoCard(
                          title: 'MEYDAN PARASI',
                          value: '${gameStore.coins}',
                          subtitle: 'Toplam',
                          icon: Icons.monetization_on_rounded,
                          color: const Color(0xFFF39C12),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BentoCard(
                          title: 'KUPALAR',
                          value: '${gameStore.trophies}',
                          subtitle: 'Elde Edilen',
                          icon: Icons.military_tech_rounded,
                          color: const Color(0xFF9B59B6),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 36),

                  // --- LAST MINUTE MODE ---
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 12),
                    child: Text('SON DAKİKA MODU', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                  Row(
                    children: [
                      Expanded(child: _MiniStatCard(title: 'GOL', value: '${gameStore.lastMinuteGoals}', icon: Icons.sports_soccer_rounded)),
                      const SizedBox(width: 8),
                      Expanded(child: _MiniStatCard(title: 'SKOR', value: '${gameStore.lastMinuteBest}', icon: Icons.score_rounded)),
                      const SizedBox(width: 8),
                      Expanded(child: _MiniStatCard(title: 'SERİ', value: '${gameStore.lastMinuteBestStreak}', icon: Icons.local_fire_department_rounded)),
                      const SizedBox(width: 8),
                      Expanded(child: _MiniStatCard(title: 'YILDIZ', value: '${gameStore.careerStars}', icon: Icons.star_rounded)),
                    ],
                  ),

                  const SizedBox(height: 36),

                  // --- BADGES ---
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 12),
                    child: Text('ROZETLER', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    clipBehavior: Clip.none,
                    child: Row(
                      children: GameStore.allBadges.entries.map((entry) {
                        final unlocked = gameStore.unlockedBadges.contains(entry.key);
                        final data = entry.value;
                        final badgeColor = data['color'] as Color? ?? Colors.white;
                        
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: const Color(0xFF111111),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                  title: Row(
                                    children: [
                                      Icon(data['icon'] as IconData, color: unlocked ? badgeColor : Colors.white38, size: 28),
                                      const SizedBox(width: 12),
                                      Expanded(child: Text(data['title'] as String, style: const TextStyle(color: Colors.white))),
                                    ],
                                  ),
                                  content: Text(
                                    '${data['desc']}\n\n${unlocked ? '✅ Kazanıldı!' : '🔒 Henüz kazanılmadı'}',
                                    style: const TextStyle(color: Colors.white70, height: 1.5),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Kapat', style: TextStyle(color: Colors.white70)),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: Container(
                              width: 90,
                              height: 110,
                              decoration: BoxDecoration(
                                color: unlocked ? badgeColor.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.02),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: unlocked ? badgeColor.withValues(alpha: 0.2) : Colors.transparent,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: unlocked ? badgeColor.withValues(alpha: 0.1) : Colors.transparent,
                                    ),
                                    child: Icon(
                                      data['icon'] as IconData,
                                      color: unlocked ? badgeColor : Colors.white24,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    data['title'] as String,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: unlocked ? Colors.white : Colors.white38,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // --- LEADERBOARD ---
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 12),
                    child: Text('GALİBİYET TABLOSU', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                  if (leaders.isEmpty)
                    _GlassContainer(
                      padding: const EdgeInsets.all(32),
                      child: const Text(
                        'İlk karşılaşmanı tamamladığında\nkazananlar burada görünecek.',
                        style: TextStyle(color: Colors.white54, height: 1.5, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    _GlassContainer(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: leaders.take(8).toList().asMap().entries.map((row) {
                          final bool isFirst = row.key == 0;
                          return Container(
                            decoration: BoxDecoration(
                              border: row.key != leaders.take(8).length - 1
                                  ? Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)))
                                  : null,
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isFirst ? const Color(0xFFFFD166) : Colors.white.withValues(alpha: 0.05),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${row.key + 1}',
                                  style: TextStyle(
                                    color: isFirst ? Colors.black : Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              title: Text(
                                row.value.key,
                                style: TextStyle(
                                  color: isFirst ? const Color(0xFFFFD166) : Colors.white, 
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              trailing: Text(
                                '${row.value.value} W',
                                style: TextStyle(
                                  color: isFirst ? const Color(0xFFFFD166) : Colors.white54,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

// ---------------------------------------------------------
// CUSTOM WIDGETS FOR MODERN LAYOUT
// ---------------------------------------------------------

class _GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _GlassContainer({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _BentoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final IconData icon;
  final Color color;

  const _BentoCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassContainer(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  subtitle,
                  style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MiniStatCard({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return _GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          Icon(icon, color: Colors.white54, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}
