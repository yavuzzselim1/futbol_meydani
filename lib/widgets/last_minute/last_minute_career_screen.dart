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

  Widget _buildGlassStatBox(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassButton(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        gameStore.tap();
        onTap();
      },
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
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

    return PageShell(
      bottomSafeArea: false,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Text(
                    'SON DAKİKA KARİYERİ',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
                ExitIcon(onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 25),
            SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
                CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic)),
              ),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0, end: 1).animate(
                  CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.workspace_premium_rounded,
                                color: gold,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'KARİYER YOLCULUĞU',
                                style: TextStyle(
                                  color: gold,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Mahalleden Meydan Arena’ya',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildGlassStatBox('ETAP (${completed}/12)', '$completed'),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildGlassStatBox('YILDIZ', '${gameStore.careerStars}'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildGlassButton(
                                  'Serbest',
                                  Icons.sports_soccer_rounded,
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const AdvancedLastMinuteScreen(),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildGlassButton(
                                  'Günlük',
                                  Icons.today_rounded,
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const AdvancedLastMinuteScreen(startDaily: true),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FadeTransition(
              opacity: Tween<double>(begin: 0, end: 1).animate(
                CurvedAnimation(parent: _controller, curve: const Interval(0.3, 0.6, curve: Curves.easeOut)),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'AŞAMALAR',
                  style: TextStyle(
                    color: muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final points = _generatePoints(width);
                final mapHeight = (12 * 120.0) + 400; // Extended so it doesn't cut off at the bottom
                
                final unlockedList = List.generate(12, (i) => i == 0 || stars[i - 1] > 0);

                return PitchBackground(
                  child: SizedBox(
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
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
          ],
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
