import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../screens/last_minute_screens.dart';
import '../../screens/match_screen.dart';
import 'dart:async';

import '../../globals.dart';
import '../../constants.dart';
import '../../widgets/common_widgets.dart';

import 'career_models.dart';
import 'last_minute_map.dart';
import 'last_minute_screen.dart';

class AdvancedLastMinuteScreen extends StatefulWidget {
  const AdvancedLastMinuteScreen({
    super.key,
    this.careerLevel,
    this.startDaily = false,
  });
  final int? careerLevel;
  final bool startDaily;
  @override
  State<AdvancedLastMinuteScreen> createState() =>
      _AdvancedLastMinuteScreenState();
}

class _AdvancedLastMinuteScreenState extends State<AdvancedLastMinuteScreen>
    with SingleTickerProviderStateMixin {
  static const challenges = <MinuteChallenge>[
    MinuteChallenge.pass,
    MinuteChallenge.dribble,
    MinuteChallenge.press,
    MinuteChallenge.throughBall,
    MinuteChallenge.dribble,
    MinuteChallenge.shot,
    MinuteChallenge.keeper,
  ];
  final random = Random();
  late final AnimationController meter;
  Timer? matchClock, eventClock;
  AdvancedMinutePhase phase = AdvancedMinutePhase.setup;
  LastMinuteDifficulty difficulty = LastMinuteDifficulty.normal;
  int seconds = 60,
      lives = 3,
      stage = 0,
      score = 0,
      streak = 0,
      bestStreak = 0,
      form = 0;
  int obstacleLane = 1,
      dribbleMoves = 0,
      pressTarget = 4,
      pressHits = 0,
      recoveryTaps = 0,
      keeperLane = 1;
  int shotPart = 0;
  int earnedStars = 0;
  double targetCenter = .5, targetWidth = .2, firstShotValue = 0;
  bool risky = false, slowMotion = false, goal = false;
  bool dailyCourse = false;
  String feedback = '';
  final List<int> route = [];
  final List<String> eventLog = [];
  List<MinuteChallenge> runChallenges = [...challenges];

  @override
  void initState() {
    super.initState();
    meter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    dailyCourse = widget.startDaily;
    if (widget.careerLevel != null) {
      difficulty = CareerLevelInfo.levels[widget.careerLevel!].difficulty;
    }
  }

  @override
  void dispose() {
    matchClock?.cancel();
    eventClock?.cancel();
    meter.dispose();
    super.dispose();
  }

  String get careerRank => gameStore.lastMinuteGoals >= 25
      ? 'Son Dakika Efsanesi'
      : gameStore.lastMinuteGoals >= 10
      ? 'Bitirici'
      : gameStore.lastMinuteGoals >= 3
      ? 'Joker Oyuncu'
      : 'Altyapı Oyuncusu';

  String challengeTitle(MinuteChallenge value) => switch (value) {
    MinuteChallenge.pass => 'Pas Penceresi',
    MinuteChallenge.dribble => 'Adam Eksilt',
    MinuteChallenge.press => 'Topu Kazan',
    MinuteChallenge.throughBall => 'Savunma Arkası',
    MinuteChallenge.shot => 'Şutu Hazırla',
    MinuteChallenge.keeper => 'Kaleciyle Karşı Karşıya',
  };

  IconData challengeIcon(MinuteChallenge value) => switch (value) {
    MinuteChallenge.pass => Icons.swap_horiz_rounded,
    MinuteChallenge.dribble => Icons.directions_run_rounded,
    MinuteChallenge.press => Icons.ads_click_rounded,
    MinuteChallenge.throughBall => Icons.trending_flat_rounded,
    MinuteChallenge.shot => Icons.sports_soccer_rounded,
    MinuteChallenge.keeper => Icons.sports_handball_rounded,
  };

  void startMatch() {
    matchClock?.cancel();
    eventClock?.cancel();
    meter.stop();
    final now = DateTime.now();
    final dailySeed = now.year * 10000 + now.month * 100 + now.day;
    final middle = <MinuteChallenge>[
      MinuteChallenge.dribble,
      MinuteChallenge.press,
      MinuteChallenge.throughBall,
      MinuteChallenge.dribble,
      MinuteChallenge.shot,
    ];
    if (dailyCourse) middle.shuffle(Random(dailySeed));
    if (widget.careerLevel != null) {
      middle.shuffle(Random(7000 + widget.careerLevel!));
    }
    runChallenges = [MinuteChallenge.pass, ...middle, MinuteChallenge.keeper];
    setState(() {
      phase = AdvancedMinutePhase.challenge;
      seconds = difficulty.seconds;
      lives = difficulty.lives;
      stage = score = streak = bestStreak = form = 0;
      risky = slowMotion = goal = false;
      earnedStars = 0;
      route.clear();
      eventLog.clear();
    });
    startChallenge();
    matchClock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || phase == AdvancedMinutePhase.finished) return;
      if (phase != AdvancedMinutePhase.challenge &&
          phase != AdvancedMinutePhase.recovery) {
        return;
      }
      if (seconds <= 1) {
        setState(() => seconds = 0);
        finish(false, 'Süre sona erdi');
      } else {
        setState(() => seconds--);
        if (seconds <= 10) gameStore.countdown();
      }
    });
    gameStore.tap(GameSound.start);
  }

  void startChallenge() {
    eventClock?.cancel();
    meter.stop();
    final current = runChallenges[stage];
    targetWidth = (difficulty.zone - (risky ? .035 : 0))
        .clamp(.10, .3)
        .toDouble();
    targetCenter = .18 + random.nextDouble() * .64;
    shotPart = 0;
    firstShotValue = 0;
    feedback = '';
    if (current == MinuteChallenge.pass ||
        current == MinuteChallenge.throughBall ||
        current == MinuteChallenge.shot) {
      final duration =
          difficulty.speed + (slowMotion ? 650 : 0) - (risky ? 120 : 0);
      meter.duration = Duration(milliseconds: max(560, duration));
      meter.repeat(reverse: true);
    } else if (current == MinuteChallenge.dribble) {
      dribbleMoves = 0;
      obstacleLane = random.nextInt(3);
      eventClock = Timer.periodic(
        Duration(milliseconds: slowMotion ? 1200 : 850),
        (_) {
          if (mounted && phase == AdvancedMinutePhase.challenge) {
            setState(() => obstacleLane = random.nextInt(3));
          }
        },
      );
    } else if (current == MinuteChallenge.press) {
      pressHits = 0;
      pressTarget = random.nextInt(9);
      eventClock = Timer.periodic(
        Duration(milliseconds: slowMotion ? 1250 : 820),
        (_) {
          if (mounted && phase == AdvancedMinutePhase.challenge) {
            setState(() => pressTarget = random.nextInt(9));
          }
        },
      );
    } else {
      keeperLane = random.nextInt(3);
      eventClock = Timer.periodic(
        Duration(milliseconds: slowMotion ? 850 : 520),
        (_) {
          if (mounted && phase == AdvancedMinutePhase.challenge) {
            setState(() => keeperLane = random.nextInt(3));
          }
        },
      );
    }
    if (mounted) setState(() {});
  }

  void timingTap() {
    final current = runChallenges[stage];
    if (phase != AdvancedMinutePhase.challenge) return;
    if (current == MinuteChallenge.shot && shotPart == 0) {
      firstShotValue = meter.value;
      shotPart = 1;
      targetCenter = .18 + random.nextDouble() * .64;
      meter.forward(from: 0);
      meter.repeat(reverse: true);
      setState(() {});
      gameStore.tap(GameSound.select);
      return;
    }
    meter.stop();
    final secondOk = (meter.value - targetCenter).abs() <= targetWidth / 2;
    if (current == MinuteChallenge.shot) {
      final firstOk = (firstShotValue - .5).abs() <= (targetWidth + .05) / 2;
      resolve(
        firstOk && secondOk,
        firstOk && secondOk ? 'Yön ve güç kusursuz!' : 'Şut dengesi bozuldu',
      );
    } else {
      resolve(
        secondOk,
        secondOk
            ? (current == MinuteChallenge.pass
                  ? 'Pas yerini buldu!'
                  : 'Savunmayı yaran pas!')
            : 'Pas araya girmedi',
      );
    }
  }

  void chooseDribbleLane(int lane) {
    if (phase != AdvancedMinutePhase.challenge ||
        runChallenges[stage] != MinuteChallenge.dribble) {
      return;
    }
    if (lane == obstacleLane) {
      resolve(false, 'Savunmacıya yakalandın');
      return;
    }
    dribbleMoves++;
    score += risky ? 65 : 40;
    form = min(100, form + 9);
    gameStore.tap(GameSound.select);
    if (dribbleMoves >= (risky ? 5 : 4)) {
      resolve(true, 'Rakibini geçtin!');
    } else {
      setState(() => obstacleLane = random.nextInt(3));
    }
  }

  void hitPressTarget(int index) {
    if (phase != AdvancedMinutePhase.challenge ||
        runChallenges[stage] != MinuteChallenge.press) {
      return;
    }
    if (index != pressTarget) {
      form = max(0, form - 5);
      gameStore.warning();
      setState(() {});
      return;
    }
    pressHits++;
    score += 35;
    form = min(100, form + 8);
    gameStore.tap(GameSound.lock);
    if (pressHits >= (risky ? 6 : 5)) {
      resolve(true, 'Presle topu kazandın!');
    } else {
      setState(() => pressTarget = random.nextInt(9));
    }
  }

  void chooseKeeperCorner(int lane) {
    if (phase != AdvancedMinutePhase.challenge ||
        runChallenges[stage] != MinuteChallenge.keeper) {
      return;
    }
    eventClock?.cancel();
    resolve(
      lane != keeperLane,
      lane != keeperLane
          ? 'Kaleciyi ters köşeye yatırdın!'
          : 'Kaleci köşeyi bildi',
    );
  }

  void resolve(bool success, String text) {
    eventClock?.cancel();
    meter.stop();
    feedback = text;
    if (success) {
      final base = risky ? 360 : 220;
      score += base + streak * 35;
      streak++;
      bestStreak = max(bestStreak, streak);
      form = min(100, form + (risky ? 28 : 20));
      eventLog.add(
        '${stage + 1}. ${challengeTitle(runChallenges[stage])}: başarılı',
      );
      stage++;
      if (stage >= runChallenges.length) {
        finish(true, text);
        return;
      }
      gameStore.tap(GameSound.lock);
      setState(() => phase = AdvancedMinutePhase.choice);
    } else {
      streak = 0;
      form = max(0, form - 25);
      eventLog.add(
        '${stage + 1}. ${challengeTitle(runChallenges[stage])}: top kaybı',
      );
      gameStore.warning();
      recoveryTaps = 0;
      setState(() => phase = AdvancedMinutePhase.recovery);
      eventClock = Timer(const Duration(seconds: 5), () {
        if (mounted && phase == AdvancedMinutePhase.recovery) losePossession();
      });
    }
  }

  void recoveryTap() {
    if (phase != AdvancedMinutePhase.recovery) return;
    final need = switch (difficulty) {
      LastMinuteDifficulty.easy => 7,
      LastMinuteDifficulty.normal => 10,
      LastMinuteDifficulty.master => 13,
    };
    if (recoveryTaps >= need) return; // Prevent double tap after finishing

    recoveryTaps++;
    gameStore.tap(GameSound.tap);
    
    if (recoveryTaps >= need) {
      eventClock?.cancel();
      score += 100;
      form = min(100, form + 12);
      feedback = 'Topu geri kazandın!';
      setState(() {});
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted && phase == AdvancedMinutePhase.recovery) {
          setState(() => phase = AdvancedMinutePhase.choice);
        }
      });
    } else {
      setState(() {});
    }
  }

  void losePossession() {
    if (phase != AdvancedMinutePhase.recovery) return;
    lives--;
    if (lives <= 0) {
      finish(false, 'Topu geri kazanamadın');
      return;
    }
    feedback = 'Bir hak kaybettin';
    setState(() => phase = AdvancedMinutePhase.choice);
  }

  void choosePath(bool chooseRisky) {
    risky = chooseRisky;
    route.add(chooseRisky ? (stage.isEven ? 1 : -1) : (stage.isEven ? -1 : 1));
    slowMotion = form >= 100;
    if (slowMotion) {
      form = 0;
      feedback = 'FORM DOLDU • YAVAŞ ÇEKİM';
      gameStore.tap(GameSound.perfect);
    }
    phase = AdvancedMinutePhase.challenge;
    startChallenge();
  }

  Future<void> finish(bool scoredGoal, String reason) async {
    if (phase == AdvancedMinutePhase.finished) return;
    matchClock?.cancel();
    eventClock?.cancel();
    meter.stop();
    goal = scoredGoal;
    feedback = reason;
    if (goal) {
      score += seconds * 18 + lives * 150 + (difficulty.index * 250);
      gameStore.perfect();
    } else {
      gameStore.warning();
    }
    await gameStore.recordLastMinute(
      score,
      stage,
      goal: goal,
      streak: bestStreak,
    );
    if (goal && widget.careerLevel != null) {
      earnedStars = seconds >= difficulty.seconds * .34 && lives >= 2
          ? 3
          : seconds >= difficulty.seconds * .14
          ? 2
          : 1;
      await gameStore.recordCareerLevel(widget.careerLevel!, earnedStars);
    }
    if (mounted) setState(() => phase = AdvancedMinutePhase.finished);
  }

  void exit() {
    matchClock?.cancel();
    eventClock?.cancel();
    meter.stop();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      title: const Text('Son Dakika'),
      actions: [
        IconButton(onPressed: exit, icon: const Icon(Icons.close_rounded)),
      ],
    ),
    body: Stack(
      children: [
        AppBackground(
          child: SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, box) {
                final compact = box.maxHeight < 720;
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: box.maxHeight - 32),
                    child: Column(
                      children: [
                        if (phase != AdvancedMinutePhase.setup) _scoreBar(),
                        SizedBox(height: compact ? 8 : 13),
                        SizedBox(
                          height: phase == AdvancedMinutePhase.setup
                              ? (compact ? 245 : 310)
                              : (compact ? 170 : 210),
                          child: LastMinuteMap(
                            stage: stage,
                            route: route,
                            goal: goal,
                          ),
                        ),
                        SizedBox(height: compact ? 9 : 14),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          child: switch (phase) {
                            AdvancedMinutePhase.setup => _setupCard(),
                            AdvancedMinutePhase.challenge => _challengeCard(),
                            AdvancedMinutePhase.choice => _choiceCard(),
                            AdvancedMinutePhase.recovery => _recoveryCard(),
                            AdvancedMinutePhase.finished => _resultCard(),
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
        if (goal &&
            phase == AdvancedMinutePhase.finished &&
            gameStore.animations)
          Positioned.fill(
            child: IgnorePointer(
              child: WinnerCelebration(
                winnerName: 'GOOOL!',
                draw: false,
                perfect: true,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _scoreBar() => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: _GlassStatBox(
              icon: Icons.timer_rounded,
              value: '$seconds',
              label: 'SANİYE',
              danger: seconds <= 10,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: _GlassStatBox(
              icon: Icons.favorite_rounded,
              value: '$lives',
              label: 'HAK',
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: _GlassStatBox(
              icon: Icons.stars_rounded,
              value: '$score',
              label: 'SKOR',
            ),
          ),
        ],
      ),
      const SizedBox(height: 7),
      Row(
        children: [
          const Text(
            'FORM',
            style: TextStyle(
              color: muted,
              fontSize: 8,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: LinearProgressIndicator(
                value: form / 100,
                minHeight: 8,
                backgroundColor: Colors.white10,
                color: form >= 100 ? const Color(0xFFE2B75A) : Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$form%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    ],
  );

  Widget _setupCard() => ClipRRect(
    key: const ValueKey('advancedSetup'),
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          children: [
            Text(
              widget.careerLevel == null
                  ? 'SON 60 SANİYE'
                  : '${CareerLevelInfo.levels[widget.careerLevel!].stadium.toUpperCase()} • ETAP ${widget.careerLevel! + 1}',
              style: const TextStyle(
                color: Color(0xFFE2B75A),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Kaleye giden yolu sen çiz.',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            const Text(
              'Altı farklı beceri oyununu geç. Güvenli veya riskli yolu seç, formunu doldur ve son vuruşu tamamla.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, height: 1.4, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (widget.careerLevel == null) ...[
              _SlidingSegmentControl<bool>(
                items: const [false, true],
                value: dailyCourse,
                labelBuilder: (val) => val ? 'Günlük Parkur' : 'Serbest Koşu',
                onChanged: (val) => setState(() => dailyCourse = val),
              ),
              const SizedBox(height: 12),
              _SlidingSegmentControl<LastMinuteDifficulty>(
                items: LastMinuteDifficulty.values,
                value: difficulty,
                labelBuilder: (val) => val.label,
                onChanged: (val) => setState(() => difficulty = val),
              ),
            ] else
              Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE2B75A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFE2B75A).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  CareerLevelInfo.levels[widget.careerLevel!].boss
                      ? Icons.emoji_events_rounded
                      : Icons.flag_rounded,
                  color: const Color(0xFFE2B75A),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    CareerLevelInfo.levels[widget.careerLevel!].title,
                    style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
                Text(
                  difficulty.label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        Text(
          '${difficulty.seconds} sn • ${difficulty.lives} hak • ${difficulty == LastMinuteDifficulty.master
              ? 'yüksek hız'
              : difficulty == LastMinuteDifficulty.easy
              ? 'geniş başarı alanı'
              : 'dengeli oyun'}',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$careerRank • ${gameStore.lastMinuteGoals} kariyer golü',
          style: const TextStyle(
            color: Color(0xFFE2B75A),
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 18),
        InkWell(
          onTap: startMatch,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE2B75A), Color(0xFFC7982F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(color: Color(0x44E2B75A), blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_arrow_rounded, color: Colors.black87, size: 22),
                SizedBox(width: 8),
                Text(
                  'Maça Gir',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  ),
),
);

  Widget _challengeCard() {
    final current = runChallenges[stage];
    return _GlassCard(
      cardKey: ValueKey('challenge$stage$shotPart'),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .05),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white12),
                ),
                child: Icon(challengeIcon(current), color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${stage + 1}/7 • ${challengeTitle(current)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${risky ? 'RİSKLİ' : 'GÜVENLİ'} YOL • Seri x$streak${slowMotion ? ' • YAVAŞ ÇEKİM' : ''}',
                      style: TextStyle(
                        color: slowMotion ? const Color(0xFFE2B75A) : Colors.white54,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (current == MinuteChallenge.pass ||
              current == MinuteChallenge.throughBall ||
              current == MinuteChallenge.shot)
            _timingGame(current)
          else if (current == MinuteChallenge.dribble)
            _dribbleGame()
          else if (current == MinuteChallenge.press)
            _pressGame()
          else
            _keeperGame(),
        ],
      ),
    );
  }

  Widget _timingGame(MinuteChallenge current) => Column(
    children: [
      Text(
        current == MinuteChallenge.shot
            ? (shotPart == 0
                  ? 'Önce yönü merkezde durdur'
                  : 'Şimdi gücü yeşil alanda durdur')
            : 'Beyaz çizgiyi yeşil pas penceresinde durdur',
        textAlign: TextAlign.center,
        style: const TextStyle(color: muted, fontSize: 11),
      ),
      const SizedBox(height: 12),
      AnimatedBuilder(
        animation: meter,
        builder: (_, _) => LayoutBuilder(
          builder: (_, c) {
            final center = current == MinuteChallenge.shot && shotPart == 0
                ? .5
                : targetCenter;
            final width = current == MinuteChallenge.shot && shotPart == 0
                ? targetWidth + .05
                : targetWidth;
            return SizedBox(
              height: 38,
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
                    left: (c.maxWidth - 14) * (center - width / 2),
                    width: (c.maxWidth - 14) * width + 14,
                    child: Container(
                      height: 21,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2B75A).withValues(alpha: .72),
                        borderRadius: BorderRadius.circular(99),
                        boxShadow: const [
                          BoxShadow(color: Color(0x77E2B75A), blurRadius: 11),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: (c.maxWidth - 14) * meter.value,
                    child: Container(
                      width: 14,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(7),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 16),
      _PremiumButton(
        label: current == MinuteChallenge.shot && shotPart == 0
            ? 'YÖNÜ KİLİTLE'
            : current == MinuteChallenge.shot
            ? 'ŞUT!'
            : 'PAS!',
        icon: Icons.touch_app_rounded,
        onPressed: timingTap,
      ),
    ],
  );

  Widget _dribbleGame() => Column(
    children: [
      Text(
        'Savunmacının olmadığı şeride dokun • $dribbleMoves/${risky ? 5 : 4}',
        style: const TextStyle(color: muted, fontSize: 11),
      ),
      const SizedBox(height: 10),
      Row(
        children: List.generate(
          3,
          (lane) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () => chooseDribbleLane(lane),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 86,
                  decoration: BoxDecoration(
                    color: lane == obstacleLane
                        ? const Color(0x44FF6B5F)
                        : Colors.white.withValues(alpha: .05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: lane == obstacleLane
                          ? const Color(0xFFFF6B5F)
                          : Colors.white24,
                    ),
                  ),
                  child: Icon(
                    lane == obstacleLane
                        ? Icons.block_rounded
                        : Icons.arrow_upward_rounded,
                    color: lane == obstacleLane
                        ? const Color(0xFFFF6B5F)
                        : const Color(0xFFE2B75A),
                    size: 34,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _pressGame() => Column(
    children: [
      Text(
        'Parlayan oyuncuya hızla bas • $pressHits/${risky ? 6 : 5}',
        style: const TextStyle(color: muted, fontSize: 11),
      ),
      const SizedBox(height: 9),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 1.3,
        ),
        itemCount: 9,
        itemBuilder: (_, i) => InkWell(
          onTap: () => hitPressTarget(i),
          borderRadius: BorderRadius.circular(13),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: i == pressTarget ? const Color(0xFFE2B75A) : Colors.white10,
              borderRadius: BorderRadius.circular(13),
              boxShadow: i == pressTarget 
                ? [const BoxShadow(color: Color(0x55E2B75A), blurRadius: 10)]
                : null,
            ),
            child: Icon(
              Icons.directions_run_rounded,
              color: i == pressTarget ? Colors.black87 : Colors.white38,
            ),
          ),
        ),
      ),
    ],
  );

  Widget _keeperGame() => Column(
    children: [
      const Text(
        'Kalecinin boş bıraktığı köşeyi seç',
        style: TextStyle(color: muted, fontSize: 11),
      ),
      const SizedBox(height: 10),
      Row(
        children: List.generate(
          3,
          (lane) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () => chooseKeeperCorner(lane),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 95,
                  decoration: BoxDecoration(
                    color: lane != keeperLane
                        ? const Color(0x33E2B75A)
                        : const Color(0x44FF6B5F),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: lane != keeperLane
                          ? const Color(0xFFE2B75A)
                          : const Color(0xFFFF6B5F),
                    ),
                  ),
                  child: Icon(
                    lane == keeperLane
                        ? Icons.sports_handball_rounded
                        : Icons.sports_soccer_rounded,
                    color: lane != keeperLane ? const Color(0xFFE2B75A) : const Color(0xFFFF6B5F),
                    size: 33,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _choiceCard() => _GlassCard(
    cardKey: ValueKey('choice$stage'),
    child: Column(
      children: [
        const Icon(Icons.alt_route_rounded, color: Color(0xFFE2B75A), size: 39),
        const SizedBox(height: 5),
        Text(
          feedback.isEmpty ? 'Hücum yolunu seç' : feedback,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PathButton(
                title: 'Güvenli',
                subtitle: 'Geniş alan\nNormal puan',
                icon: Icons.shield_outlined,
                color: const Color(0xFFE2B75A),
                onTap: () => choosePath(false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PathButton(
                title: 'Riskli',
                subtitle: 'Dar alan\nYüksek puan',
                icon: Icons.local_fire_department_rounded,
                color: const Color(0xFFFF6B5F),
                onTap: () => choosePath(true),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _recoveryCard() {
    final need = switch (difficulty) {
      LastMinuteDifficulty.easy => 7,
      LastMinuteDifficulty.normal => 10,
      LastMinuteDifficulty.master => 13,
    };
    return _GlassCard(
      cardKey: ValueKey('recovery$stage'),
      child: Column(
        children: [
          const Icon(
            Icons.crisis_alert_rounded,
            color: Color(0xFFFF6B5F),
            size: 43,
          ),
          const SizedBox(height: 5),
          const Text(
            'TOP RAKİPTE!',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: Colors.white),
          ),
          const SizedBox(height: 5),
          const Text(
            '5 saniye içinde seri pres yap ve topu geri kazan.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 11),
          LinearProgressIndicator(
            value: recoveryTaps / need,
            minHeight: 10,
            borderRadius: BorderRadius.circular(8),
            backgroundColor: Colors.white10,
            color: const Color(0xFFFF6B5F),
          ),
          const SizedBox(height: 16),
          _PremiumButton(
            label: 'PRES! $recoveryTaps/$need',
            icon: Icons.ads_click_rounded,
            onPressed: recoveryTap,
            isDanger: true,
          ),
        ],
      ),
    );
  }

  Widget _resultCard() => _GlassCard(
    cardKey: const ValueKey('advancedResult'),
    child: Column(
      children: [
        Icon(
          goal ? Icons.emoji_events_rounded : Icons.flag_rounded,
          color: goal ? const Color(0xFFFFD166) : Colors.white38,
          size: 48,
        ),
        const SizedBox(height: 5),
        Text(
          goal ? 'SON DAKİKA GOLÜ!' : 'HÜCUM SONA ERDİ',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(feedback, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 11),
        Row(
          children: [
            Expanded(
              child: ProfileStat(value: '$score', label: 'PUAN'),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ProfileStat(value: '$bestStreak', label: 'EN İYİ SERİ'),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ProfileStat(value: '$stage/7', label: 'AŞAMA'),
            ),
          ],
        ),
        if (widget.careerLevel != null && goal) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (i) => Icon(
                i < earnedStars
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                color: const Color(0xFFFFD166),
                size: 30,
              ),
            ),
          ),
        ],
        const SizedBox(height: 9),
        Text(
          '${dailyCourse ? 'Günlük Parkur' : 'Serbest Koşu'} • ${difficulty.label} • ${route.length} yol seçimi',
          style: const TextStyle(
            color: Color(0xFFE2B75A),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '$careerRank • ${gameStore.lastMinuteGoals} kariyer golü',
          style: const TextStyle(
            color: Color(0xFFFFD166),
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 16),
        if (widget.careerLevel != null && goal && widget.careerLevel! + 1 < CareerLevelInfo.levels.length) ...[
          _PremiumButton(
            label: 'Sonraki Bölüm',
            icon: Icons.fast_forward_rounded,
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => AdvancedLastMinuteScreen(
                    careerLevel: widget.careerLevel! + 1,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: exit,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.careerLevel == null ? Icons.home_rounded : Icons.map_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.careerLevel == null ? 'Ana Menü' : 'Harita',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: startMatch,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFE2B75A), Color(0xFFC7982F)]),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.refresh_rounded, color: Colors.black87, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Tekrar',
                        style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _PathButton extends StatelessWidget {
  const _PathButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: color.withValues(alpha: .10),
    borderRadius: BorderRadius.circular(17),
    child: InkWell(
      onTap: () {
        gameStore.tap(GameSound.select);
        onTap();
      },
      borderRadius: BorderRadius.circular(17),
      child: Container(
        height: 105,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: color.withValues(alpha: .6)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 5),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontSize: 9, height: 1.25),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SlidingSegmentControl<T> extends StatefulWidget {
  final List<T> items;
  final String Function(T) labelBuilder;
  final T value;
  final ValueChanged<T> onChanged;

  const _SlidingSegmentControl({
    super.key,
    required this.items,
    required this.labelBuilder,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_SlidingSegmentControl<T>> createState() => _SlidingSegmentControlState<T>();
}

class _SlidingSegmentControlState<T> extends State<_SlidingSegmentControl<T>> {
  double? _dragPosition;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = widget.items.length;
          final tabWidth = constraints.maxWidth / count;
          final currentIndex = widget.items.indexOf(widget.value);

          double leftPos = tabWidth * currentIndex;
          if (_dragPosition != null) {
            leftPos = _dragPosition!.clamp(0.0, tabWidth * (count - 1));
          }

          const textStyle = TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          );

          return TweenAnimationBuilder<double>(
            tween: Tween<double>(end: leftPos),
            duration: _dragPosition != null ? Duration.zero : const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            builder: (context, currentLeft, child) {
              return Stack(
                children: [
                  Row(
                    children: widget.items.map((item) => Expanded(
                      child: Center(
                        child: Text(
                          widget.labelBuilder(item),
                          style: textStyle.copyWith(color: Colors.white54),
                        ),
                      ),
                    )).toList(),
                  ),
                  Positioned(
                    left: currentLeft,
                    top: 0,
                    bottom: 0,
                    width: tabWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white24),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Stack(
                          children: [
                            Positioned(
                              left: -currentLeft,
                              top: 0,
                              bottom: 0,
                              width: constraints.maxWidth,
                              child: Row(
                                children: widget.items.map((item) => Expanded(
                                  child: Center(
                                    child: Text(
                                      widget.labelBuilder(item),
                                      style: textStyle.copyWith(color: Colors.white),
                                    ),
                                  ),
                                )).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) {
                        final index = (details.localPosition.dx / tabWidth).floor().clamp(0, count - 1);
                        final target = widget.items[index];
                        if (target != widget.value) widget.onChanged(target);
                      },
                      onHorizontalDragStart: (details) {
                        setState(() => _dragPosition = tabWidth * currentIndex);
                      },
                      onHorizontalDragUpdate: (details) {
                        if (_dragPosition != null) {
                          setState(() => _dragPosition = _dragPosition! + details.delta.dx);
                        }
                      },
                      onHorizontalDragEnd: (details) {
                        if (_dragPosition != null) {
                          final index = ((_dragPosition! + (tabWidth/2)) / tabWidth).floor().clamp(0, count - 1);
                          final target = widget.items[index];
                          setState(() => _dragPosition = null);
                          if (target != widget.value) widget.onChanged(target);
                        }
                      },
                      onHorizontalDragCancel: () {
                        if (_dragPosition != null) setState(() => _dragPosition = null);
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final Key? cardKey;
  const _GlassCard({super.key, required this.child, this.cardKey});
  
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      key: cardKey,
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PremiumButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isDanger;
  
  const _PremiumButton({
    super.key,
    required this.label, 
    required this.icon, 
    this.onPressed, 
    this.isDanger = false
  });

  @override
  State<_PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<_PremiumButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (widget.onPressed != null) {
          setState(() => _isPressed = true);
        }
      },
      onTapUp: (_) {
        if (widget.onPressed != null) {
          setState(() => _isPressed = false);
          widget.onPressed!();
        }
      },
      onTapCancel: () {
        if (widget.onPressed != null) {
          setState(() => _isPressed = false);
        }
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.isDanger 
                  ? [const Color(0xFFFF6B5F), const Color(0xFFD63B30)]
                  : [const Color(0xFFE2B75A), const Color(0xFFC7982F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              if (!_isPressed)
                BoxShadow(
                  color: (widget.isDanger ? const Color(0xFFFF6B5F) : const Color(0xFFE2B75A)).withValues(alpha: 0.35), 
                  blurRadius: 12, 
                  offset: const Offset(0, 4)
                ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: Colors.black87, size: 22),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassStatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool danger;

  const _GlassStatBox({
    required this.label,
    required this.value,
    required this.icon,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFFF6B5F) : const Color(0xFFE2B75A);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(color: color.withValues(alpha: 0.5), blurRadius: 10),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
