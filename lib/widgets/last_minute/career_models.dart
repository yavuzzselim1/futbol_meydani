import 'package:flutter/material.dart';
import '../../screens/last_minute_screens.dart';

import '../../globals.dart';
import '../../constants.dart';

class CareerLevelInfo {
  const CareerLevelInfo(this.title, this.stadium, this.difficulty, this.boss);
  final String title, stadium;
  final LastMinuteDifficulty difficulty;
  final bool boss;
  
  static const levels = <CareerLevelInfo>[
    CareerLevelInfo('İlk Düdük', 'Mahalle Sahası', LastMinuteDifficulty.easy, false),
    CareerLevelInfo('Dar Alan', 'Mahalle Sahası', LastMinuteDifficulty.easy, false),
    CareerLevelInfo('Hızlı Hücum', 'Mahalle Sahası', LastMinuteDifficulty.normal, false),
    CareerLevelInfo('Mahalle Finali', 'Mahalle Sahası', LastMinuteDifficulty.normal, true),
    CareerLevelInfo('Deplasman', 'Şehir Stadı', LastMinuteDifficulty.normal, false),
    CareerLevelInfo('Yoğun Pres', 'Şehir Stadı', LastMinuteDifficulty.normal, false),
    CareerLevelInfo('Kırılma Anı', 'Şehir Stadı', LastMinuteDifficulty.master, false),
    CareerLevelInfo('Şehir Derbisi', 'Şehir Stadı', LastMinuteDifficulty.master, true),
    CareerLevelInfo('Büyük Sahne', 'Meydan Arena', LastMinuteDifficulty.master, false),
    CareerLevelInfo('Usta Savunma', 'Meydan Arena', LastMinuteDifficulty.master, false),
    CareerLevelInfo('Kupa Gecesi', 'Meydan Arena', LastMinuteDifficulty.master, false),
    CareerLevelInfo('Meydan Finali', 'Meydan Arena', LastMinuteDifficulty.master, true),
  ];
}

class CareerNode extends StatelessWidget {
  const CareerNode({
    super.key,
    required this.number,
    required this.info,
    required this.stars,
    required this.unlocked,
    required this.onTap,
    this.animationValue = 1.0,
  });
  
  final int number, stars;
  final CareerLevelInfo info;
  final bool unlocked;
  final VoidCallback onTap;
  final double animationValue;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFD166);
    final isBoss = info.boss;
    
    final isLeft = (number - 1) % 2 == 0;
    
    final textBox = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: unlocked ? gold.withValues(alpha: 0.5) : Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            info.title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: unlocked ? Colors.white : muted,
            ),
          ),
          if (unlocked)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                3,
                (i) => Icon(
                  i < stars ? Icons.star_rounded : Icons.star_border_rounded,
                  color: gold,
                  size: 12,
                ),
              ),
            )
        ],
      ),
    );

    
    return Transform.scale(
      scale: animationValue,
      child: Opacity(
        opacity: (animationValue * (unlocked ? 1.0 : 0.6)).clamp(0.0, 1.0),
        child: GestureDetector(
          onTap: unlocked
              ? () {
                  gameStore.tap(GameSound.select);
                  onTap();
                }
              : null,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: isBoss ? 70 : 60,
                height: isBoss ? 70 : 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: unlocked
                      ? (isBoss ? gold.withValues(alpha: 0.2) : Colors.black87)
                      : Colors.black54,
                  border: Border.all(
                    color: unlocked
                        ? (isBoss ? gold.withValues(alpha: 0.8) : Colors.white60)
                        : Colors.white24,
                    width: isBoss ? 3 : 2,
                  ),
                  boxShadow: unlocked
                      ? [
                          BoxShadow(
                            color: (isBoss ? gold : Colors.white).withValues(alpha: 0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: Icon(
                    isBoss
                        ? Icons.emoji_events_rounded
                        : unlocked
                            ? Icons.sports_soccer_rounded
                            : Icons.lock_rounded,
                    color: unlocked ? (isBoss ? gold : Colors.white) : muted,
                    size: isBoss ? 32 : 28,
                  ),
                ),
              ),
              Positioned(
                left: isLeft ? (isBoss ? 70.0 : 60.0) : null,
                right: isLeft ? null : (isBoss ? 70.0 : 60.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isLeft) textBox,
                    Container(
                      width: 12,
                      height: 2,
                      color: unlocked ? gold.withValues(alpha: 0.5) : Colors.white24,
                    ),
                    if (isLeft) textBox,
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class CareerPathPainter extends CustomPainter {
  final List<Offset> points;
  final List<bool> unlockedStatus;
  
  CareerPathPainter(this.points, this.unlockedStatus);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    
    final paintLocked = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final paintUnlocked = Paint()
      ..color = const Color(0xFFFFD166)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
      
    final glowPaint = Paint()
      ..color = const Color(0xFFFFD166).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final isUnlocked = unlockedStatus[i + 1];

      // Adjust gap so it perfectly touches the edge without penetrating the circle
      final startY = p1.dy + 31;
      final endY = p2.dy - 31;

      final path = Path();
      path.moveTo(p1.dx, startY);
      
      final midY = (p1.dy + p2.dy) / 2;
      path.cubicTo(p1.dx, midY, p2.dx, midY, p2.dx, endY);
      
      canvas.drawPath(path, isUnlocked ? glowPaint : paintLocked);
      canvas.drawPath(path, isUnlocked ? paintUnlocked : paintLocked);
    }
  }

  @override
  bool shouldRepaint(covariant CareerPathPainter oldDelegate) => true;
}
