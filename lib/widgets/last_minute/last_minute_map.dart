import 'dart:math';
import 'package:flutter/material.dart';

import '../../constants.dart';

class LastMinuteMap extends StatelessWidget {
  const LastMinuteMap({
    super.key,
    required this.stage,
    required this.route,
    required this.goal,
  });
  final int stage;
  final List<int> route;
  final bool goal;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF236F48), Color(0xFF0B3B26)],
      ),
      borderRadius: BorderRadius.circular(25),
      border: Border.all(color: const Color(0xFF71F39A).withValues(alpha: .5), width: 1.5),
      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 18)],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: CustomPaint(
        painter: LastMinuteMapPainter(stage: stage, route: route, goal: goal),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

class LastMinuteMapPainter extends CustomPainter {
  LastMinuteMapPainter({
    required this.stage,
    required this.route,
    required this.goal,
  });
  final int stage;
  final List<int> route;
  final bool goal;
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white30
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRect(
      Rect.fromLTWH(12, 12, size.width - 24, size.height - 24),
      line,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width / 2, 35),
        width: size.width * .38,
        height: 46,
      ),
      line,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height * .53),
      size.width * .1,
      line,
    );
    for (var i = 0; i < 6; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          12,
          12 + i * (size.height - 24) / 6,
          size.width - 24,
          (size.height - 24) / 12,
        ),
        Paint()..color = const Color(0x0FFFFFFF),
      );
    }
    final nodes = <Offset>[];
    var lane = 0.0;
    for (var i = 0; i < 8; i++) {
      if (i > 0 && i - 1 < route.length) {
        lane = (lane + route[i - 1] * .34).clamp(-.68, .68).toDouble();
      }
      nodes.add(
        Offset(
          size.width / 2 + lane * size.width * .36,
          size.height - 30 - i * (size.height - 62) / 7,
        ),
      );
    }
    for (var i = 1; i < nodes.length; i++) {
      final reached = i <= stage;
      final pathColor = reached ? const Color(0xFF71F39A) : Colors.white24;
      final path = Paint()
        ..color = pathColor
        ..strokeWidth = reached ? 4.5 : 2
        ..strokeCap = StrokeCap.round;
      if (reached) {
         path.maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);
      }
      canvas.drawLine(nodes[i - 1], nodes[i], path);
    }
    for (var i = 0; i < nodes.length; i++) {
      final reached = i <= stage;
      final color = reached ? const Color(0xFF71F39A) : const Color(0xFF1E1E1E);
      
      canvas.drawCircle(
        nodes[i],
        reached ? 12 : 9,
        Paint()..color = color,
      );
      canvas.drawCircle(
        nodes[i],
        reached ? 12 : 9,
        Paint()
          ..color = reached ? Colors.white : Colors.white54
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      if (i == stage && i < 7) {
        canvas.drawCircle(
          nodes[i],
          19,
          Paint()..color = const Color(0xFF71F39A).withValues(alpha: .25),
        );
      }
    }
    final ballAt = nodes[min(stage, 7)];
    final tp = TextPainter(
      text: TextSpan(
        text: goal ? '⚽' : '●',
        style: TextStyle(fontSize: goal ? 24 : 12, color: goal ? Colors.white : Colors.black87),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, ballAt - Offset(tp.width / 2, tp.height / 2));
    final goalText = TextPainter(
      text: const TextSpan(
        text: 'KALE',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    goalText.paint(canvas, Offset(size.width / 2 - goalText.width / 2, 14));
  }

  @override
  bool shouldRepaint(covariant LastMinuteMapPainter old) =>
      old.stage != stage ||
      old.goal != goal ||
      old.route.length != route.length;
}
