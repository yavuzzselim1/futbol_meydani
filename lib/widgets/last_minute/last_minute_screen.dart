import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';

import '../../globals.dart';
import '../../constants.dart';
import '../../widgets/common_widgets.dart';

import 'last_minute_map.dart';

class LastMinuteScreen extends StatefulWidget {
  const LastMinuteScreen({super.key});
  @override
  State<LastMinuteScreen> createState() => _LastMinuteScreenState();
}

class _LastMinuteScreenState extends State<LastMinuteScreen>
    with SingleTickerProviderStateMixin {
  static const actions = [
    'İlk pas',
    'Dar alanda dripling',
    'Duvar pası',
    'Rakibi eksilt',
    'Ara pası',
    'Ceza sahasına gir',
    'Son vuruş',
  ];
  late final AnimationController aim;
  final random = Random();
  Timer? clock;
  LastMinutePhase phase = LastMinutePhase.intro;
  int seconds = 60, stage = 0, lives = 3, score = 0, streak = 0;
  double targetCenter = .5, targetWidth = .25;
  bool lastHit = false;
  int lastPoints = 0;
  final List<int> route = [];

  @override
  void initState() {
    super.initState();
    aim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    );
  }

  @override
  void dispose() {
    clock?.cancel();
    aim.dispose();
    super.dispose();
  }

  void startGame() {
    setState(() {
      phase = LastMinutePhase.aiming;
      seconds = 60;
      stage = 0;
      lives = 3;
      score = 0;
      streak = 0;
      route.clear();
    });
    prepareAim();
    clock?.cancel();
    clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || phase == LastMinutePhase.finished) return;
      if (seconds <= 1) {
        setState(() => seconds = 0);
        finish(false);
      } else {
        setState(() => seconds--);
        if (seconds <= 10) gameStore.countdown();
      }
    });
    gameStore.tap(GameSound.start);
  }

  void prepareAim() {
    targetWidth = max(.105, .27 - stage * .022).toDouble();
    targetCenter = .18 + random.nextDouble() * .64;
    aim.duration = Duration(milliseconds: max(620, 1250 - stage * 75));
    aim.repeat(reverse: true);
  }

  void shoot() {
    if (phase != LastMinutePhase.aiming) return;
    aim.stop();
    final distance = (aim.value - targetCenter).abs();
    lastHit = distance <= targetWidth / 2;
    lastPoints = lastHit
        ? (120 + (1 - distance / (targetWidth / 2)) * 180).round() + streak * 25
        : 0;
    if (lastHit) {
      score += lastPoints;
      streak++;
      stage++;
      gameStore.tap(
        stage == actions.length ? GameSound.perfect : GameSound.lock,
      );
    } else {
      lives--;
      streak = 0;
      gameStore.warning();
    }
    if (stage >= actions.length) {
      finish(true);
      return;
    }
    if (lives <= 0) {
      finish(false);
      return;
    }
    setState(() => phase = LastMinutePhase.decision);
  }

  void chooseRoute(int lane) {
    if (lastHit) route.add(lane);
    setState(() => phase = LastMinutePhase.aiming);
    prepareAim();
    gameStore.tap(GameSound.select);
  }

  Future<void> finish(bool goal) async {
    if (phase == LastMinutePhase.finished) return;
    clock?.cancel();
    aim.stop();
    if (goal) {
      score += seconds * 15 + lives * 100;
      gameStore.perfect();
    } else {
      gameStore.tap(GameSound.warning);
    }
    await gameStore.recordLastMinute(score, stage);
    if (mounted) setState(() => phase = LastMinutePhase.finished);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Son Dakika'),
      actions: [
        IconButton(
          tooltip: 'Çık',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
    body: AppBackground(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            final compact = box.maxHeight < 700;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight - 34),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: LastMinuteStat(
                            icon: Icons.timer_rounded,
                            value: '$seconds',
                            label: 'SANİYE',
                            danger: seconds <= 10,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: LastMinuteStat(
                            icon: Icons.favorite_rounded,
                            value: '$lives',
                            label: 'HAK',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: LastMinuteStat(
                            icon: Icons.stars_rounded,
                            value: '$score',
                            label: 'SKOR',
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 10 : 16),
                    SizedBox(
                      height: compact ? 260 : 330,
                      child: LastMinuteMap(
                        stage: stage,
                        route: route,
                        goal:
                            phase == LastMinutePhase.finished &&
                            stage >= actions.length,
                      ),
                    ),
                    SizedBox(height: compact ? 10 : 16),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: switch (phase) {
                        LastMinutePhase.intro => _intro(),
                        LastMinutePhase.aiming => _aiming(),
                        LastMinutePhase.decision => _decision(),
                        LastMinutePhase.finished => _finished(),
                        _ => const SizedBox.shrink(),
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );

  Widget _intro() => CardBox(
    key: const ValueKey('intro'),
    child: Column(
      children: [
        const Icon(
          Icons.sports_soccer_rounded,
          color: Color(0xFFFF6B5F),
          size: 46,
        ),
        const SizedBox(height: 8),
        const Text(
          'KALEYE 60 SANİYE',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 7),
        const Text(
          'Hareketli gösterge yeşil bölgedeyken dokun. Başarılı hamlelerle yolunu seç, 7 aşamayı tamamla ve golü bul.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, height: 1.4),
        ),
        const SizedBox(height: 14),
        Text(
          'En iyi skor ${gameStore.lastMinuteBest} • En uzak aşama ${gameStore.lastMinuteFurthest}/7',
          style: const TextStyle(
            color: green,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        PrimaryButton(
          label: 'Maçı Başlat',
          icon: Icons.play_arrow_rounded,
          onPressed: startGame,
        ),
      ],
    ),
  );

  Widget _aiming() => CardBox(
    key: ValueKey('aim$stage'),
    child: Column(
      children: [
        Text(
          '${stage + 1}/7  •  ${actions[stage]}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        Text(
          'Seri x$streak',
          style: const TextStyle(
            color: green,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 18),
        AnimatedBuilder(
          animation: aim,
          builder: (_, _) => LayoutBuilder(
            builder: (_, c) => SizedBox(
              height: 34,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Positioned(
                    left: (c.maxWidth - 14) * (targetCenter - targetWidth / 2),
                    width: (c.maxWidth - 14) * targetWidth + 14,
                    child: Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: green.withValues(alpha: .72),
                        borderRadius: BorderRadius.circular(99),
                        boxShadow: const [
                          BoxShadow(color: Color(0x8871F39A), blurRadius: 12),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: (c.maxWidth - 14) * aim.value,
                    child: Container(
                      width: 14,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(7),
                        boxShadow: const [
                          BoxShadow(color: Colors.white54, blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 15),
        PrimaryButton(
          label: 'ŞİMDİ!',
          icon: Icons.touch_app_rounded,
          onPressed: shoot,
        ),
      ],
    ),
  );

  Widget _decision() => CardBox(
    key: ValueKey('decision$stage$lives'),
    child: Column(
      children: [
        Icon(
          lastHit ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: lastHit ? green : const Color(0xFFFF6B5F),
          size: 42,
        ),
        const SizedBox(height: 7),
        Text(
          lastHit ? 'Harika hamle! +$lastPoints' : 'Topu kaybettin!',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        Text(
          lastHit
              ? 'Hücum yönünü seç.'
              : '$lives hakkın kaldı. Aynı hamleyi tekrar dene.',
          style: const TextStyle(color: muted),
        ),
        const SizedBox(height: 14),
        if (lastHit)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => chooseRoute(-1),
                  icon: const Icon(Icons.turn_left_rounded),
                  label: const Text('Sol Kanat'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => chooseRoute(1),
                  icon: const Icon(Icons.turn_right_rounded),
                  label: const Text('Sağ Kanat'),
                ),
              ),
            ],
          )
        else
          PrimaryButton(
            label: 'Tekrar Dene',
            icon: Icons.refresh_rounded,
            onPressed: () => chooseRoute(0),
          ),
      ],
    ),
  );

  Widget _finished() {
    final goal = stage >= actions.length;
    return CardBox(
      key: const ValueKey('finished'),
      child: Column(
        children: [
          Icon(
            goal ? Icons.emoji_events_rounded : Icons.sports_soccer_outlined,
            color: goal ? const Color(0xFFFFD166) : muted,
            size: 50,
          ),
          const SizedBox(height: 7),
          Text(
            goal ? 'GOOOL!' : 'MAÇ BİTTİ',
            style: const TextStyle(fontSize: 31, fontWeight: FontWeight.w900),
          ),
          Text(
            goal
                ? 'Son dakikada kaleye ulaştın.'
                : 'Bu kez ${stage + 1}. hamlede kaldın.',
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 12),
          Text(
            '$score PUAN',
            style: const TextStyle(
              color: green,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Ana Menü'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: startGame,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Tekrar Oyna'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class LastMinuteStat extends StatelessWidget {
  const LastMinuteStat({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.danger = false,
  });
  final IconData icon;
  final String value, label;
  final bool danger;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      color: panel,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(
        color: danger ? const Color(0xFFFF6B5F) : Colors.white10,
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 17, color: danger ? const Color(0xFFFF6B5F) : green),
        const SizedBox(width: 6),
        Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: danger ? const Color(0xFFFF6B5F) : Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: muted,
                fontSize: 7,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

enum LastMinutePhase { menu, map, summary, intro, aiming, decision, finished }
