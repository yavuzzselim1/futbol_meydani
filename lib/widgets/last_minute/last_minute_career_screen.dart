import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math';

import '../../globals.dart';
import '../../constants.dart';
import '../../widgets/common_widgets.dart';

import 'career_models.dart';
import 'advanced_last_minute_screen.dart';

class LastMinuteCareerScreen extends StatefulWidget {
  const LastMinuteCareerScreen({super.key});
  @override
  State<LastMinuteCareerScreen> createState() => _LastMinuteCareerScreenState();
}

class _LastMinuteCareerScreenState extends State<LastMinuteCareerScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> openLevel(int index) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdvancedLastMinuteScreen(careerLevel: index),
      ),
    );
    if (mounted) setState(() {});
  }

  List<Offset> _generatePoints(double width) {
    List<Offset> points = [];
    double y = 60;
    for (int i = 0; i < 12; i++) {
      double x = (i % 2 == 0) ? width * 0.25 : width * 0.75;
      points.add(Offset(x, y));
      y += 120;
    }
    return points;
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        gameStore.tap();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14)),
                Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stars = gameStore.lastMinuteCareerStars;
    final completed = stars.where((value) => value > 0).length;
    final gold = const Color(0xFFFFD166);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Son Dakika Kariyeri',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Colors.white),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded, color: gold, size: 13),
                const SizedBox(width: 4),
                Text(
                  '${gameStore.careerStars}  •  $completed/12',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              const Positioned.fill(
                child: PitchBackground(child: SizedBox()),
              ),
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
                          CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic)),
                        ),
                        child: FadeTransition(
                          opacity: Tween<double>(begin: 0, end: 1).animate(
                            CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.workspace_premium_rounded, color: gold, size: 13),
                                  const SizedBox(width: 5),
                                  Text(
                                    'KARİYER YOLCULUĞU',
                                    style: TextStyle(
                                      color: gold,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                "Mahalleden Meydan Arena'ya",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'Futbol serüvenine katıl ve tüm aşamaları geç.',
                                style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildActionCard(
                                      title: 'Serbest',
                                      subtitle: 'Antrenman modu',
                                      icon: Icons.sports_soccer_rounded,
                                      color: const Color(0xFF71F39A),
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const AdvancedLastMinuteScreen()),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildActionCard(
                                      title: 'Günlük',
                                      subtitle: 'Ödüllü maç',
                                      icon: Icons.today_rounded,
                                      color: const Color(0xFFFFD166),
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const AdvancedLastMinuteScreen(startDaily: true)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      FadeTransition(
                        opacity: Tween<double>(begin: 0, end: 1).animate(
                          CurvedAnimation(parent: _controller, curve: const Interval(0.3, 0.6, curve: Curves.easeOut)),
                        ),
                        child: const Text(
                          'AŞAMALAR',
                          style: TextStyle(
                            color: muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final points = _generatePoints(width);
                          final mapHeight = (12 * 120.0) + 400;
                          final unlockedList = List.generate(12, (i) => i == 0 || stars[i - 1] > 0);

                          return SizedBox(
                            width: width,
                            height: mapHeight,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: AnimatedBuilder(
                                    animation: _controller,
                                    builder: (context, child) {
                                      final pathOpacity = Curves.easeOut.transform(
                                        max(0.0, min(1.0, (_controller.value - 0.4) / 0.3)),
                                      );
                                      return Opacity(
                                        opacity: pathOpacity,
                                        child: CustomPaint(
                                          painter: CareerPathPainter(points, unlockedList),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                ...List.generate(12, (i) {
                                  final point = points[i];
                                  final isBoss = CareerLevelInfo.levels[i].boss;
                                  final nodeWidth = isBoss ? 70.0 : 60.0;

                                  return Positioned(
                                    left: point.dx - nodeWidth / 2,
                                    top: point.dy - 35,
                                    child: AnimatedBuilder(
                                      animation: _controller,
                                      builder: (context, child) {
                                        final start = 0.3 + (i * 0.05);
                                        final end = min(1.0, start + 0.2);
                                        final val = Curves.easeOutBack.transform(
                                          max(0.0, min(1.0, (_controller.value - start) / (end - start))),
                                        );
                                        return CareerNode(
                                          number: i + 1,
                                          info: CareerLevelInfo.levels[i],
                                          stars: stars[i],
                                          unlocked: unlockedList[i],
                                          onTap: () => openLevel(i),
                                          animationValue: val,
                                        );
                                      },
                                    ),
                                  );
                                }),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PitchBackground extends StatelessWidget {
  const PitchBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF102A20).withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: const Border(
          top: BorderSide(color: Colors.white24, width: 2),
          left: BorderSide(color: Colors.white24, width: 2),
          right: BorderSide(color: Colors.white24, width: 2),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: CustomPaint(
                painter: _PitchPainter(),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;

    final segments = (h / 200).ceil();
    for (int i = 1; i < segments; i++) {
      double y = i * 200.0;
      canvas.drawLine(Offset(0, y), Offset(w, y), paint);
      if (i % 2 == 0) {
        canvas.drawCircle(Offset(w / 2, y), 40, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
