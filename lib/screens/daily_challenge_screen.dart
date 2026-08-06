import 'package:flutter/material.dart';
import 'match_screen.dart';

import 'package:futbol_meydani/constants.dart';
import 'package:futbol_meydani/globals.dart';
import 'package:futbol_meydani/models/game_data.dart';
import 'package:futbol_meydani/utils/helpers.dart';
import 'package:futbol_meydani/widgets/common_widgets.dart';

class DailyChallengeCard extends StatelessWidget {
  const DailyChallengeCard({
    super.key,
    required this.done,
    required this.onTap,
  });
  final bool done;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFD166);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () {
          gameStore.tap();
          onTap();
        },
        borderRadius: BorderRadius.circular(18),
        splashColor: gold.withValues(alpha: 0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: const Color(0xFF151100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: gold.withValues(alpha: .35)),
                ),
                child: Icon(
                  done
                      ? Icons.check_circle_rounded
                      : Icons.local_fire_department_rounded,
                  color: gold,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GÜNÜN GÖREVİ',
                      style: TextStyle(
                        color: gold,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      done
                          ? 'Tamamlandı • Tekrar oynayabilirsin'
                          : 'Bugünün özel hedefini yakala',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: gold.withValues(alpha: .3)),
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: gold,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DailyChallengeScreen extends StatefulWidget {
  const DailyChallengeScreen({super.key, required this.data});
  final GameData data;
  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen> {
  late final Question question;
  late final Target target;
  int stage = 0;
  List<Pick> picks = [];
  num total = 0, difference = 0;
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    question = widget.data.questions[seed % widget.data.questions.length];
    target = question.targets[(seed ~/ 7) % question.targets.length];
  }

  void finish(List<Pick> selected) {
    picks = [...selected];
    while (picks.length < 5) {
      picks.add(emptyPick());
    }
    total = picks.fold<num>(0, (sum, pick) => sum + pick.value);
    difference = (target.value - total).abs();
    gameStore.recordDaily(difference);
    difference == 0 ? gameStore.perfect() : gameStore.success();
    setState(() => stage = 2);
  }

  @override
  Widget build(BuildContext context) {
    final prompt = question.prompt.replaceAll('{target}', '${target.value}');
    if (stage == 1) {
      return SelectionView(
        data: widget.data,
        question: question,
        target: target,
        prompt: prompt,
        playerName: 'Günün Kadrosu',
        playerIndex: 0,
        onLocked: finish,
        onExit: () => Navigator.pop(context),
      );
    }
    if (stage == 2) {
      return Scaffold(
        appBar: AppBar(title: const Text('Günün Görevi')),
        body: Stack(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    const Text(
                      'GÖREV TAMAMLANDI',
                      style: TextStyle(
                        color: Color(0xFFFFD166),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      difference == 0
                          ? 'TAM İSABET!'
                          : 'Hedefe $difference kaldı',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Hedef ${target.value} • Senin toplamın $total',
                      style: const TextStyle(
                        color: green,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: ListView.separated(
                        itemCount: picks.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 7),
                        itemBuilder: (_, i) =>
                            RevealCard(pick: picks[i], open: true),
                      ),
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: 'Ana Ekrana Dön',
                      icon: Icons.home_rounded,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),
            if (difference == 0 && gameStore.animations)
              const Positioned.fill(
                child: IgnorePointer(
                  child: WinnerCelebration(
                    winnerName: 'TAM İSABET!',
                    draw: false,
                    perfect: true,
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return PageShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const RoundPill(text: 'GÜNÜN GÖREVİ'),
              ExitIcon(onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 25),
          const Text(
            'BUGÜNE ÖZEL',
            style: TextStyle(
              color: Color(0xFFFFD166),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            question.title,
            style: const TextStyle(
              fontSize: 31,
              height: 1.05,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          CardBox(
            child: Column(
              children: [
                Text(
                  '${target.value}',
                  style: const TextStyle(
                    color: green,
                    fontSize: 62,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  'HEDEF TOPLAM',
                  style: TextStyle(
                    color: muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  prompt,
                  textAlign: TextAlign.center,
                  style: const TextStyle(height: 1.45),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (gameStore.dailyDone)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Center(
                child: Text(
                  'Bugünkü görevi tamamladın; yeniden deneyebilirsin.',
                  style: TextStyle(color: muted, fontSize: 11),
                ),
              ),
            ),
          PrimaryButton(
            label: 'Görevi Başlat',
            icon: Icons.local_fire_department_rounded,
            onPressed: () => setState(() => stage = 1),
          ),
        ],
      ),
    );
  }
}
