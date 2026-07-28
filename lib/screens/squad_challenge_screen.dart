import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import '../models/multi_league.dart';

import 'package:futbol_meydani/constants.dart';
import 'package:futbol_meydani/globals.dart';
import 'package:futbol_meydani/models/game_data.dart';
import 'package:futbol_meydani/utils/helpers.dart';
import 'package:futbol_meydani/widgets/common_widgets.dart';
import 'package:futbol_meydani/utils/glass_toast.dart';
import 'package:futbol_meydani/widgets/squad_pitch.dart';
import 'package:futbol_meydani/screens/match_screen.dart';

// ─── DrawCeremony ───────────────────────────────────────────────────
class DrawCeremony extends StatefulWidget {
  const DrawCeremony({
    super.key,
    required this.round,
    required this.season,
    required this.onReady,
    required this.onExit,
  });
  final LeagueDrawRound round;
  final String season;
  final VoidCallback onReady, onExit;
  @override
  State<DrawCeremony> createState() => _DrawCeremonyState();
}

class _DrawCeremonyState extends State<DrawCeremony> {
  int stage = 0;
  @override
  void initState() {
    super.initState();
    reveal();
  }

  Future<void> reveal() async {
    for (var next = 1; next <= 4; next++) {
      await Future.delayed(
        Duration(milliseconds: gameStore.animations ? 680 : 90),
      );
      if (!mounted) return;
      gameStore.tap(next == 4 ? GameSound.lock : GameSound.reveal);
      setState(() => stage = next);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AppBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const RoundPill(text: 'MEYDAN KURASI'),
                  ExitIcon(onPressed: widget.onExit),
                ],
              ),
              const Spacer(),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: stage < 4 ? pi * 6 : pi * 8),
                duration: Duration(
                  milliseconds: gameStore.animations ? 700 : 100,
                ),
                builder: (_, angle, child) =>
                    Transform.rotate(angle: angle, child: child),
                child: Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: green.withValues(alpha: .12),
                    border: Border.all(color: green, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Color(0x5571F39A), blurRadius: 26),
                    ],
                  ),
                  child: const Icon(
                    Icons.sports_soccer_rounded,
                    color: green,
                    size: 49,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'KURA ÇEKİLİYOR',
                style: TextStyle(
                  color: green,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Bu turun meydanı belli oluyor.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 22),
              DrawRevealTile(
                index: '01',
                label: 'GÖREV',
                value: widget.round.title,
                visible: stage >= 1,
                icon: Icons.flag_rounded,
              ),
              const SizedBox(height: 8),
              DrawRevealTile(
                index: '02',
                label: 'LİG',
                value: '${widget.round.leagueName} • ${widget.season}',
                visible: stage >= 2,
                icon: Icons.public_rounded,
              ),
              const SizedBox(height: 8),
              DrawRevealTile(
                index: '03',
                label: 'TAKIMLAR',
                value: widget.round.teamNames.join('  •  '),
                visible: stage >= 3,
                icon: Icons.shield_rounded,
              ),
              const SizedBox(height: 8),
              DrawRevealTile(
                index: '04',
                label: 'HEDEF',
                value: '${widget.round.target} ${widget.round.unit}',
                visible: stage >= 4,
                icon: Icons.gps_fixed_rounded,
                highlighted: true,
              ),
              const Spacer(),
              PrimaryButton(
                label: stage >= 4
                    ? 'Kadro Kurmaya Başla'
                    : 'Kura Devam Ediyor…',
                icon: Icons.arrow_forward_rounded,
                onPressed: stage >= 4 ? widget.onReady : null,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ─── DrawRevealTile ─────────────────────────────────────────────────
class DrawRevealTile extends StatelessWidget {
  const DrawRevealTile({
    super.key,
    required this.index,
    required this.label,
    required this.value,
    required this.visible,
    required this.icon,
    this.highlighted = false,
  });
  final String index, label, value;
  final bool visible, highlighted;
  final IconData icon;
  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: visible ? 1 : .22,
    duration: const Duration(milliseconds: 320),
    child: AnimatedScale(
      scale: visible ? 1 : .96,
      duration: const Duration(milliseconds: 320),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 62),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: highlighted && visible ? green.withValues(alpha: .13) : panel,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: highlighted && visible ? green : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Text(
              index,
              style: TextStyle(
                color: visible ? green : muted,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 11),
            Icon(icon, color: visible ? green : muted, size: 21),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: muted,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    visible ? value : '••••••••',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: visible ? Colors.white : muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ─── SquadSetupScreen ───────────────────────────────────────────────
class SquadSetupScreen extends StatefulWidget {
  const SquadSetupScreen({super.key, required this.data});
  final GameData data;
  @override
  State<SquadSetupScreen> createState() => _SquadSetupScreenState();
}

class _SquadSetupScreenState extends State<SquadSetupScreen> {
  final one = TextEditingController(text: 'Selim');
  final two = TextEditingController(text: 'Mert');
  String? selectedLeagueId;
  @override
  void dispose() {
    one.dispose();
    two.dispose();
    super.dispose();
  }

  void start() {
    final a = one.text.trim(), b = two.text.trim();
    if (a.isEmpty || b.isEmpty || normalize(a) == normalize(b)) {
      GlassToast.show(context, 'İki farklı oyuncu adı yaz.', isError: true);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SquadChallengeScreen(
          data: widget.data,
          names: [a, b],
          preferredLeagueId: selectedLeagueId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(backgroundColor: bg, title: const Text('Meydan Kadrosu')),
    body: AppBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Kadro düellosunu kur.',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Görev, lig ve takımlar kurayla belirlenecek; iki oyuncu gizli kadrolar kuracak.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 26),
            TextField(
              controller: one,
              maxLength: 18,
              decoration: const InputDecoration(
                labelText: 'Oyuncu 1',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: two,
              maxLength: 18,
              decoration: const InputDecoration(
                labelText: 'Oyuncu 2',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Lig seçimi',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            const Text(
              'Rastgele bırakırsan her düelloda dört ligden biri kurayla belirlenir.',
              style: TextStyle(color: muted, fontSize: 11),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                ChoiceChip(
                  label: const Text('🎲 Rastgele'),
                  selected: selectedLeagueId == null,
                  onSelected: (_) => setState(() => selectedLeagueId = null),
                ),
                ...?widget.data.multiLeague?.leagues.entries.map(
                  (league) => ChoiceChip(
                    label: Text(league.value),
                    selected: selectedLeagueId == league.key,
                    onSelected: (_) =>
                        setState(() => selectedLeagueId = league.key),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Kadro Düellosunu Başlat',
              icon: Icons.stadium,
              onPressed: start,
            ),
          ],
        ),
      ),
    ),
  );
}

// ─── SquadPhase Enum ────────────────────────────────────────────────
enum SquadPhase { draw, selection, handoff, result }

// ─── SquadChallengeScreen ───────────────────────────────────────────
class SquadChallengeScreen extends StatefulWidget {
  const SquadChallengeScreen({
    super.key,
    required this.data,
    required this.names,
    this.preferredLeagueId,
  });
  final GameData data;
  final List<String> names;
  final String? preferredLeagueId;
  @override
  State<SquadChallengeScreen> createState() => _SquadChallengeScreenState();
}

class _SquadChallengeScreenState extends State<SquadChallengeScreen> {
  final search = TextEditingController();
  List<List<Pick>> squads = [[], []];
  int currentPlayer = 0;
  SquadPhase phase = SquadPhase.selection;
  late Question question;
  late Target target;
  late Formation formation;
  LeagueDrawRound? drawRound;
  late List<Pick> initialSuggestions;
  Timer? squadTimer;
  int secondsLeft = 120;
  List<int> revealedBySide = [0, 0];
  bool resultRevealing = false;
  bool resultRecorded = false;
  Pick? spotlightPick;
  int? spotlightSide;
  bool spotlightValueVisible = false;

  List<Pick> get selected => squads[currentPlayer];
  @override
  void initState() {
    super.initState();
    newDuel(notify: false);
  }

  @override
  void dispose() {
    squadTimer?.cancel();
    search.dispose();
    super.dispose();
  }

  void startSquadTimer() {
    squadTimer?.cancel();
    secondsLeft = 120;
    squadTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || phase != SquadPhase.selection) return;
      if (secondsLeft <= 1) {
        gameStore.warning();
        setState(() => secondsLeft = 0);
        lockSquad(timedOut: true);
      } else {
        if (secondsLeft <= 11) gameStore.countdown();
        setState(() => secondsLeft--);
      }
    });
  }

  List<Pick> allPicks() {
    if (drawRound != null) {
      return drawRound!.candidates
          .map((player) => Pick(player, player.stats[drawRound!.metric] ?? 0))
          .toList();
    }
    return question.candidates
        .map(
          (id) => Pick(
            widget.data.players[id]!,
            widget.data.answers['${question.id}:$id']!,
          ),
        )
        .toList();
  }

  void newDuel({bool notify = true}) {
    if (widget.data.multiLeague != null) {
      drawRound = widget.data.multiLeague!.randomRound(
        leagueId: widget.preferredLeagueId,
      );
      final drawn = drawRound!;
      question = Question(
        id: drawn.metric,
        title: drawn.title,
        prompt:
            '${drawn.prompt} Kurada çıkan ${drawn.teamNames.join(', ')} takımlarından seçim yap.',
        unit: drawn.unit,
        definition: '${drawn.leagueName} • ${widget.data.multiLeague!.season}',
        candidates: drawn.candidates.map((player) => player.id).toList(),
        targets: [Target(value: drawn.target, difficulty: 'Kura')],
      );
      target = question.targets.first;
      formation = Formation.forMetric(drawn.metric);
    } else {
      drawRound = null;
      final pool = widget.data.questions
          .where(
            (q) => !{
              'saves',
              'clean_sheets',
            }.contains(q.id.replaceFirst('pl2425_', '')),
          )
          .toList();
      question = pool[Random().nextInt(pool.length)];
      formation = Formation.forMetric(question.id.replaceFirst('pl2425_', ''));
      final reference = <Pick>[];
      final candidates = allPicks();
      for (final position in ['GK', 'DF', 'MF', 'FW']) {
        final positionPool =
            candidates.where((e) => e.player.position == position).toList()
              ..sort((a, b) => b.value.compareTo(a.value));
        final useful = positionPool.take(min(35, positionPool.length)).toList()
          ..shuffle(Random());
        reference.addAll(useful.take(formation.quota(position)));
      }
      target = Target(
        value: reference.fold<num>(0, (sum, item) => sum + item.value),
        difficulty: 'Kadro',
      );
    }
    squads = [[], []];
    currentPlayer = 0;
    phase = drawRound == null ? SquadPhase.selection : SquadPhase.draw;
    search.clear();
    revealedBySide = [0, 0];
    resultRevealing = false;
    resultRecorded = false;
    spotlightPick = null;
    spotlightSide = null;
    spotlightValueVisible = false;
    initialSuggestions = buildSuggestions();
    if (phase == SquadPhase.selection) startSquadTimer();
    if (notify && mounted) setState(() {});
  }

  void finishDraw() {
    setState(() => phase = SquadPhase.selection);
    startSquadTimer();
  }

  List<Pick> buildSuggestions() {
    final all = allPicks();
    final ranked = [...all]..sort((a, b) => b.value.compareTo(a.value));
    final relevant = ranked.take(2).toList();
    final ids = relevant.map((e) => e.player.id).toSet();
    final randoms = all.where((e) => !ids.contains(e.player.id)).toList()
      ..shuffle(Random());
    return [...randoms.take(5), ...relevant]..shuffle(Random());
  }

  List<Pick> get results {
    final q = normalize(search.text),
        selectedIds = selected.map((e) => e.player.id).toSet();
    if (q.isEmpty) {
      return initialSuggestions
          .where((e) => !selectedIds.contains(e.player.id))
          .toList();
    }
    final list = allPicks().where((pick) {
      if (selectedIds.contains(pick.player.id)) return false;
      final terms = [
        pick.player.name,
        ...pick.player.aliases,
        pick.player.team,
      ];
      return terms.any(
        (v) =>
            normalize(v).contains(q) ||
            normalize(v).split(' ').any((w) => w.startsWith(q)),
      );
    }).toList()..sort((a, b) => a.player.name.compareTo(b.player.name));
    return list.take(40).toList();
  }

  int positionCount(String position) =>
      selected.where((e) => e.player.position == position).length;
  void add(Pick pick) {
    if (positionCount(pick.player.position) >=
        formation.quota(pick.player.position)) {
      GlassToast.show(
        context,
        '${positionName(pick.player.position)} kontenjanı dolu.',
        isError: true,
      );
      return;
    }
    gameStore.tap(GameSound.select);
    setState(() => selected.add(pick));
  }

  void lockSquad({bool timedOut = false}) {
    squadTimer?.cancel();
    if (currentPlayer == 0) {
      setState(() => phase = SquadPhase.handoff);
      return;
    }
    setState(() => phase = SquadPhase.result);
  }

  void secondReady() {
    setState(() {
      currentPlayer = 1;
      phase = SquadPhase.selection;
      search.clear();
      initialSuggestions = buildSuggestions();
    });
    startSquadTimer();
  }

  num total(int side) =>
      squads[side].fold<num>(0, (sum, item) => sum + item.value);
  int? winner() {
    final d0 = (target.value - total(0)).abs(),
        d1 = (target.value - total(1)).abs();
    return d0 == d1
        ? null
        : d0 < d1
        ? 0
        : 1;
  }

  List<Pick> orderedSquad(int side) {
    final ordered = <Pick>[];
    for (final position in ['GK', 'DF', 'MF', 'FW']) {
      final players = squads[side]
          .where((pick) => pick.player.position == position)
          .toList();
      for (var index = 0; index < formation.quota(position); index++) {
        ordered.add(
          index < players.length ? players[index] : emptyPick(position),
        );
      }
    }
    return ordered;
  }

  Future<void> revealSquads() async {
    if (resultRevealing) return;
    setState(() {
      resultRevealing = true;
      revealedBySide = [0, 0];
    });
    final ordered = [orderedSquad(0), orderedSquad(1)];
    for (var slot = 0; slot < 7; slot++) {
      for (var side = 0; side < 2; side++) {
        if (!mounted) return;
        setState(() {
          spotlightPick = ordered[side][slot];
          spotlightSide = side;
          spotlightValueVisible = false;
        });
        final revealBoost = gameStore.unlockedBoosts.contains('boost_reveal');
        final speedMult = revealBoost ? 2 : 1;
        gameStore.tap(GameSound.reveal);
        await Future.delayed(
          Duration(
            milliseconds: gameStore.animations
                ? 1000 ~/ speedMult
                : 120 ~/ speedMult,
          ),
        );
        if (!mounted) return;
        setState(() {
          spotlightValueVisible = true;
          revealedBySide[side] = slot + 1;
        });
        await Future.delayed(
          Duration(
            milliseconds: gameStore.animations
                ? 750 ~/ speedMult
                : 80 ~/ speedMult,
          ),
        );
        if (!mounted) return;
        setState(() {
          spotlightPick = null;
          spotlightSide = null;
        });
        await Future.delayed(
          Duration(
            milliseconds: gameStore.animations
                ? 180 ~/ speedMult
                : 30 ~/ speedMult,
          ),
        );
      }
    }
    if (mounted) {
      final winning = winner();
      final bestDifference = min(
        (target.value - total(0)).abs(),
        (target.value - total(1)).abs(),
      );
      if (!resultRecorded) {
        resultRecorded = true;
        gameStore.recordMatch(
          winning == null ? null : widget.names[winning],
          bestDifference,
        );
      }
      bestDifference == 0 ? gameStore.perfect() : gameStore.success();
      setState(() => resultRevealing = false);
    }
  }

  @override
  Widget build(BuildContext context) => switch (phase) {
    SquadPhase.draw => DrawCeremony(
      round: drawRound!,
      season: widget.data.multiLeague!.season,
      onReady: finishDraw,
      onExit: () => Navigator.of(context).popUntil((route) => route.isFirst),
    ),
    SquadPhase.selection => buildSelection(),
    SquadPhase.handoff => HandoffView(
      first: widget.names[0],
      second: widget.names[1],
      onReady: secondReady,
      onExit: () => Navigator.of(context).popUntil((route) => route.isFirst),
    ),
    SquadPhase.result => buildResult(),
  };

  Widget buildSelection() => Scaffold(
    appBar: AppBar(
      backgroundColor: bg,
      automaticallyImplyLeading: false,
      title: Text('${widget.names[currentPlayer]} kadro kuruyor'),
      actions: [
        RoundPill(text: formatTime(secondsLeft)),
        const SizedBox(width: 5),
        RoundPill(text: formation.label),
        ExitIcon(
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ],
    ),
    body: SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
                  child: CardBox(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                question.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Text(
                              'HEDEF ${target.value}',
                              style: const TextStyle(
                                color: green,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          question.prompt.replaceAll(
                            '{target}',
                            '${target.value}',
                          ),
                          style: const TextStyle(
                            color: muted,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                        if (drawRound != null) ...[
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                Chip(label: Text(drawRound!.leagueName)),
                                const SizedBox(width: 5),
                                ...drawRound!.teamNames.expand(
                                  (name) => [
                                    Chip(label: Text(name)),
                                    const SizedBox(width: 5),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: SquadPitch(
                    formation: formation,
                    picks: selected,
                    height: (MediaQuery.sizeOf(context).width * .72)
                        .clamp(255.0, 310.0)
                        .toDouble(),
                    onRemove: (pick) => setState(() => selected.remove(pick)),
                    onDrop: add,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  child: TextField(
                    controller: search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Futbolcu veya takım ara…',
                      suffixText: '${selected.length}/7',
                    ),
                  ),
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((_, index) {
                final pick = results[index],
                    full =
                        positionCount(pick.player.position) >=
                        formation.quota(pick.player.position);
                return LongPressDraggable<Pick>(
                  data: pick,
                  delay: const Duration(milliseconds: 220),
                  dragAnchorStrategy: pointerDragAnchorStrategy,
                  feedback: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: 158,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: panel2,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: green),
                        boxShadow: const [
                          BoxShadow(color: Colors.black45, blurRadius: 12),
                        ],
                      ),
                      child: Text(
                        '${pick.player.name} • ${positionName(pick.player.position)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: .35,
                    child: Card(
                      color: panel,
                      child: ListTile(
                        dense: true,
                        title: Text(pick.player.name),
                        subtitle: Text(pick.player.team),
                      ),
                    ),
                  ),
                  child: Card(
                    color: panel,
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.drag_indicator, color: muted),
                      title: Text(
                        pick.player.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${pick.player.team} • ${positionName(pick.player.position)}',
                      ),
                      trailing: Icon(
                        full ? Icons.block : Icons.add_circle,
                        color: full ? muted : green,
                      ),
                      onTap: () => add(pick),
                    ),
                  ),
                );
              }, childCount: results.length),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(14),
            sliver: SliverToBoxAdapter(
              child: PrimaryButton(
                label: selected.length == 7
                    ? 'Kadroyu Kilitle'
                    : '${7 - selected.length} futbolcu daha seç',
                icon: Icons.lock,
                onPressed: selected.length == 7 ? lockSquad : null,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget buildResult() {
    final winning = winner();
    final fullyRevealed = revealedBySide.every((count) => count >= 7);
    final perfectHit =
        (target.value - total(0)).abs() == 0 ||
        (target.value - total(1)).abs() == 0;
    final showCelebration =
        fullyRevealed && !resultRevealing && gameStore.animations;
    final winnerText = winning == null
        ? 'BERABERE'
        : widget.names[winning].toUpperCase();
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
              child: Column(
                children: [
                  Text(
                    fullyRevealed
                        ? 'MEYDANIN KAZANANI'
                        : 'KADROLAR AÇIKLANIYOR',
                    style: const TextStyle(
                      color: green,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.7,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fullyRevealed ? winnerText : 'KADRO DÜELLOSU',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: fullyRevealed ? 37 : 25,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.1,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: green.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: green.withValues(alpha: .35)),
                    ),
                    child: Text(
                      'HEDEF  ${target.value} ${question.unit}',
                      style: const TextStyle(
                        color: green,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (drawRound != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${drawRound!.leagueName} • ${drawRound!.teamNames.join(' • ')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: muted,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 7),
                  Row(
                    children: List.generate(
                      2,
                      (side) => Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: panel,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: winning == side && fullyRevealed
                                  ? green
                                  : Colors.white12,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                widget.names[side],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                fullyRevealed
                                    ? '${total(side)}'
                                    : '${revealedBySide[side]}/7',
                                style: const TextStyle(
                                  fontSize: 20,
                                  color: green,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Row(
                          children: List.generate(
                            2,
                            (side) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      widget.names[side],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Expanded(
                                      child: SquadPitch(
                                        formation: formation,
                                        picks: squads[side],
                                        height: null,
                                        revealCount: revealedBySide[side],
                                        showValues: true,
                                        compact: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (spotlightPick != null)
                          RevealSpotlight(
                            name: widget.names[spotlightSide!],
                            pick: spotlightPick!,
                            unit: question.unit,
                            showValue: spotlightValueVisible,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (revealedBySide.every((count) => count == 0) &&
                      !resultRevealing)
                    PrimaryButton(
                      label: 'Kadroları Tek Tek Aç',
                      icon: Icons.visibility,
                      onPressed: revealSquads,
                    )
                  else if (!fullyRevealed)
                    PrimaryButton(
                      label: 'Oyuncular Açılıyor…',
                      icon: Icons.hourglass_bottom,
                      onPressed: null,
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              gameStore.tap(GameSound.home);
                              Navigator.of(
                                context,
                              ).popUntil((route) => route.isFirst);
                            },
                            icon: const Icon(Icons.home),
                            label: const Text('Ana Menü'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              gameStore.tap(GameSound.refresh);
                              newDuel();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Yeni Düello'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (showCelebration)
            Positioned.fill(
              child: IgnorePointer(
                child: WinnerCelebration(
                  winnerName: winnerText,
                  draw: winning == null,
                  perfect: perfectHit,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
