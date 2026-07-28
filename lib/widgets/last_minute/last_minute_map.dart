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
        colors: [Color(0xFF236F48), Color(0xFF0D442D)],
      ),
      borderRadius: BorderRadius.circular(25),
      border: Border.all(color: green.withValues(alpha: .65), width: 1.5),
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
      ..color = Colors.white38
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
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
      final path = Paint()
        ..color = i <= stage ? green : Colors.white24
        ..strokeWidth = i <= stage ? 5 : 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(nodes[i - 1], nodes[i], path);
    }
    for (var i = 0; i < nodes.length; i++) {
      final reached = i <= stage;
      canvas.drawCircle(
        nodes[i],
        reached ? 13 : 10,
        Paint()..color = reached ? green : panel2,
      );
      canvas.drawCircle(
        nodes[i],
        reached ? 13 : 10,
        Paint()
          ..color = Colors.white54
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      if (i == stage && i < 7) {
        canvas.drawCircle(
          nodes[i],
          19,
          Paint()..color = green.withValues(alpha: .25),
        );
      }
    }
    final ballAt = nodes[min(stage, 7)];
    final tp = TextPainter(
      text: TextSpan(
        text: goal ? '⚽' : '●',
        style: TextStyle(fontSize: goal ? 23 : 14, color: bg),
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
