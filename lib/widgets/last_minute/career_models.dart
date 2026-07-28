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
    CareerLevelInfo(
      'İlk Düdük',
      'Mahalle Sahası',
      LastMinuteDifficulty.easy,
      false,
    ),
    CareerLevelInfo(
      'Dar Alan',
      'Mahalle Sahası',
      LastMinuteDifficulty.easy,
      false,
    ),
    CareerLevelInfo(
      'Hızlı Hücum',
      'Mahalle Sahası',
      LastMinuteDifficulty.normal,
      false,
    ),
    CareerLevelInfo(
      'Mahalle Finali',
      'Mahalle Sahası',
      LastMinuteDifficulty.normal,
      true,
    ),
    CareerLevelInfo(
      'Deplasman',
      'Şehir Stadı',
      LastMinuteDifficulty.normal,
      false,
    ),
    CareerLevelInfo(
      'Yoğun Pres',
      'Şehir Stadı',
      LastMinuteDifficulty.normal,
      false,
    ),
    CareerLevelInfo(
      'Kırılma Anı',
      'Şehir Stadı',
      LastMinuteDifficulty.master,
      false,
    ),
    CareerLevelInfo(
      'Şehir Derbisi',
      'Şehir Stadı',
      LastMinuteDifficulty.master,
      true,
    ),
    CareerLevelInfo(
      'Büyük Sahne',
      'Meydan Arena',
      LastMinuteDifficulty.master,
      false,
    ),
    CareerLevelInfo(
      'Usta Savunma',
      'Meydan Arena',
      LastMinuteDifficulty.master,
      false,
    ),
    CareerLevelInfo(
      'Kupa Gecesi',
      'Meydan Arena',
      LastMinuteDifficulty.master,
      false,
    ),
    CareerLevelInfo(
      'Meydan Finali',
      'Meydan Arena',
      LastMinuteDifficulty.master,
      true,
    ),
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
  });
  final int number, stars;
  final CareerLevelInfo info;
  final bool unlocked;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: unlocked
        ? () {
            gameStore.tap(GameSound.select);
            onTap();
          }
        : null,
    child: SizedBox(
      width: 84,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: info.boss ? 62 : 54,
            height: info.boss ? 62 : 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: unlocked
                  ? (info.boss ? const Color(0xFFFFD166) : panel2)
                  : const Color(0xFF202723),
              border: Border.all(
                color: unlocked
                    ? (info.boss ? const Color(0xFFFFD166) : green)
                    : Colors.white12,
                width: 2,
              ),
              boxShadow: unlocked
                  ? [
                      BoxShadow(
                        color: (info.boss ? const Color(0xFFFFD166) : green)
                            .withValues(alpha: .24),
                        blurRadius: 15,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              info.boss
                  ? Icons.emoji_events_rounded
                  : unlocked
                  ? Icons.sports_soccer_rounded
                  : Icons.lock_rounded,
              color: unlocked ? (info.boss ? bg : green) : muted,
              size: info.boss ? 31 : 25,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '$number. ${info.title}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: unlocked ? Colors.white : muted,
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (unlocked)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (i) => Icon(
                  i < stars ? Icons.star_rounded : Icons.star_border_rounded,
                  color: const Color(0xFFFFD166),
                  size: 12,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class CareerPathPainter extends CustomPainter {
  CareerPathPainter({required this.points, required this.stars});
  final List<Offset> points;
  final List<int> stars;
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 1; i < points.length; i++) {
      final unlocked = stars[i - 1] > 0;
      final paint = Paint()
        ..color = unlocked ? green.withValues(alpha: .8) : Colors.white12
        ..strokeWidth = unlocked ? 5 : 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final path = Path()
        ..moveTo(points[i - 1].dx, points[i - 1].dy)
        ..cubicTo(
          size.width / 2,
          points[i - 1].dy - 22,
          size.width / 2,
          points[i].dy + 22,
          points[i].dx,
          points[i].dy,
        );
      canvas.drawPath(path, paint);
    }
    final glow = Paint()
      ..shader =
          const RadialGradient(
            colors: [Color(0x2271F39A), Colors.transparent],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width / 2, size.height / 2),
              radius: size.width,
            ),
          );
    canvas.drawRect(Offset.zero & size, glow);
  }

  @override
  bool shouldRepaint(covariant CareerPathPainter old) =>
      old.stars.join() != stars.join();
}
