import 'package:flutter/material.dart';

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

class _LastMinuteCareerScreenState extends State<LastMinuteCareerScreen> {
  Future<void> openLevel(int index) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdvancedLastMinuteScreen(careerLevel: index),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final stars = gameStore.lastMinuteCareerStars;
    final completed = stars.where((value) => value > 0).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Son Dakika Kariyeri')),
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF713029), Color(0xFF163C2D)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0x66FF6B5F)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'KARİYER YOLCULUĞU',
                      style: TextStyle(
                        color: Color(0xFFFFD166),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Mahalleden Meydan Arena’ya',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$completed/12 etap • ${gameStore.careerStars}/36 yıldız • ${gameStore.lastMinuteGoals} kariyer golü',
                      style: const TextStyle(
                        color: green,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: completed / 12,
                      minHeight: 9,
                      borderRadius: BorderRadius.circular(9),
                      backgroundColor: Colors.black26,
                      color: green,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdvancedLastMinuteScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.sports_soccer_rounded),
                      label: const Text('Serbest Oyna'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const AdvancedLastMinuteScreen(startDaily: true),
                        ),
                      ),
                      icon: const Icon(Icons.today_rounded),
                      label: const Text('Günlük Parkur'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Container(
                height: 990,
                decoration: BoxDecoration(
                  color: const Color(0xAA092018),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white10),
                ),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final points = List.generate(12, (i) {
                      final x = switch (i % 4) {
                        0 => .20,
                        1 => .72,
                        2 => .30,
                        _ => .67,
                      };
                      return Offset(box.maxWidth * x, 935 - i * 78);
                    });
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: CareerPathPainter(
                              points: points,
                              stars: [...stars],
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 18,
                          top: 18,
                          child: _CareerZoneLabel(
                            title: 'MEYDAN ARENA',
                            color: Color(0xFFFFD166),
                          ),
                        ),
                        const Positioned(
                          left: 18,
                          top: 330,
                          child: _CareerZoneLabel(
                            title: 'ŞEHİR STADI',
                            color: Color(0xFF5EC8FF),
                          ),
                        ),
                        const Positioned(
                          left: 18,
                          top: 648,
                          child: _CareerZoneLabel(
                            title: 'MAHALLE SAHASI',
                            color: green,
                          ),
                        ),
                        ...List.generate(12, (i) {
                          final unlocked = i == 0 || stars[i - 1] > 0;
                          final info = CareerLevelInfo.levels[i];
                          return Positioned(
                            left: points[i].dx - 42,
                            top: points[i].dy - 42,
                            child: CareerNode(
                              number: i + 1,
                              info: info,
                              stars: stars[i],
                              unlocked: unlocked,
                              onTap: () => openLevel(i),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CareerZoneLabel extends StatelessWidget {
  const _CareerZoneLabel({required this.title, required this.color});
  final String title;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: color.withValues(alpha: .5)),
    ),
    child: Text(
      title,
      style: TextStyle(
        color: color,
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
      ),
    ),
  );
}
