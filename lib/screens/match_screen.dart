import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:futbol_meydani/constants.dart';
import 'package:futbol_meydani/globals.dart';
import 'package:futbol_meydani/models/game_data.dart';
import 'package:futbol_meydani/utils/helpers.dart';
import 'package:futbol_meydani/widgets/common_widgets.dart';

// ─── Phase Enum ─────────────────────────────────────────────────────
enum Phase { task, selection, handoff, ready, reveal }

// ─── MatchScreen ────────────────────────────────────────────────────
class MatchScreen extends StatefulWidget {
  const MatchScreen({
    super.key,
    required this.data,
    required this.names,
    required this.roundCount,
  });
  final GameData data;
  final List<String> names;
  final int roundCount;
  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  late List<Question> deck;
  int round = 1, currentPlayer = 0;
  Phase phase = Phase.task;
  List<List<Pick>> picks = [[], []];
  List<int> matchScore = [0, 0];
  int revealed = 0;
  bool revealing = false;
  bool matchRecorded = false;

  Question get question => deck[(round - 1) % deck.length];
  Target get target => question.targets[(round - 1) % question.targets.length];
  String get prompt =>
      question.prompt.replaceAll('{target}', '${target.value}');

  List<String> get displayNames => widget.names.map((n) {
    if (n == gameStore.playerName &&
        gameStore.currentAvatar == 'avatar_captain') {
      return '$n 🎖️';
    }
    return n;
  }).toList();

  @override
  void initState() {
    super.initState();
    deck = [...widget.data.questions]..shuffle(Random());
  }

  void beginSelection() => setState(() {
    phase = Phase.selection;
    currentPlayer = 0;
  });
  void locked(List<Pick> selected) {
    final evaluated = [...selected];
    while (evaluated.length < 5) {
      evaluated.add(emptyPick());
    }
    picks[currentPlayer] = evaluated;
    setState(() => phase = currentPlayer == 0 ? Phase.handoff : Phase.ready);
  }

  void secondReady() => setState(() {
    currentPlayer = 1;
    phase = Phase.selection;
  });
  void openResults() => setState(() {
    phase = Phase.reveal;
    revealed = 0;
  });

  Future<void> reveal() async {
    if (revealing) return;
    setState(() => revealing = true);
    int baseDuration = gameStore.animations ? 550 : 70;
    if (gameStore.unlockedBoosts.contains('boost_reveal')) {
      baseDuration = baseDuration ~/ 2;
    }
    for (var i = 1; i <= 10; i++) {
      gameStore.tap(GameSound.reveal);
      await Future.delayed(Duration(milliseconds: baseDuration));
      if (!mounted) return;
      setState(() => revealed = i);
    }
    final totals = [sum(picks[0]), sum(picks[1])];
    final distances = totals.map((v) => (target.value - v).abs()).toList();
    int? winner;
    if (distances[0] != distances[1]) {
      winner = distances[0] < distances[1] ? 0 : 1;
      matchScore[winner]++;
    }
    if (!mounted) return;
    final perfectSide = distances.indexWhere((distance) => distance == 0);
    if (perfectSide >= 0) {
      gameStore.perfect();
      if (gameStore.animations) {
        showGeneralDialog<void>(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black54,
          pageBuilder: (_, _, _) => Material(
            color: Colors.transparent,
            child: WinnerCelebration(
              winnerName: displayNames[perfectSide].toUpperCase(),
              draw: false,
              perfect: true,
            ),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 3600));
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WinnerDialog(
        names: displayNames,
        totals: totals,
        target: target.value,
        winner: winner,
      ),
    );
    if (!mounted) return;
    if (perfectSide < 0) gameStore.success();
    setState(() => revealing = false);
  }

  num sum(List<Pick> items) => items.fold<num>(0, (a, b) => a + b.value);

  void nextRound() {
    if (round == widget.roundCount) {
      final winner = matchScore[0] == matchScore[1]
          ? null
          : (matchScore[0] > matchScore[1] ? 0 : 1);
      final bestDifference = min(
        (target.value - sum(picks[0])).abs(),
        (target.value - sum(picks[1])).abs(),
      );
      if (!matchRecorded) {
        matchRecorded = true;
        gameStore.recordMatch(
          winner == null ? null : widget.names[winner],
          bestDifference,
        );
      }
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => MatchEndDialog(
          names: displayNames,
          score: matchScore,
          winner: winner,
          close: () {
            Navigator.pop(context);
            Navigator.pop(context);
          },
        ),
      );
      return;
    }
    setState(() {
      round++;
      currentPlayer = 0;
      picks = [[], []];
      revealed = 0;
      phase = Phase.task;
    });
  }

  Future<void> askExit() async {
    final leader = matchScore[0] == matchScore[1]
        ? null
        : (matchScore[0] > matchScore[1] ? 0 : 1);
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: gameStore.activeThemePanel2Color,
        icon: const Icon(Icons.exit_to_app, color: Color(0xFFFF7777), size: 42),
        title: Text(
          leader == null
              ? 'Maç şu anda berabere'
              : 'Şu anki lider ${displayNames[leader]}',
          textAlign: TextAlign.center,
        ),
        content: Text(
          '${displayNames[0]} ${matchScore[0]} — ${matchScore[1]} ${displayNames[1]}\nAna menüye dönmek istiyor musunuz?',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              gameStore.tap();
              Navigator.pop(dialogContext, false);
            },
            child: const Text('Maça Devam Et'),
          ),
          FilledButton(
            onPressed: () {
              gameStore.tap(GameSound.lock);
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Oyundan Çık'),
          ),
        ],
      ),
    );
    if (shouldExit == true && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) askExit();
    },
    child: switch (phase) {
      Phase.task => TaskView(
        round: round,
        roundCount: widget.roundCount,
        question: question,
        target: target,
        prompt: prompt,
        onStart: beginSelection,
        onExit: askExit,
      ),
      Phase.selection => SelectionView(
        data: widget.data,
        question: question,
        target: target,
        prompt: prompt,
        playerName: displayNames[currentPlayer],
        playerIndex: currentPlayer,
        onLocked: locked,
        onExit: askExit,
      ),
      Phase.handoff => HandoffView(
        first: displayNames[0],
        second: displayNames[1],
        onReady: secondReady,
        onExit: askExit,
      ),
      Phase.ready => ReadyView(
        names: displayNames,
        onOpen: openResults,
        onExit: askExit,
      ),
      Phase.reveal => RevealView(
        names: displayNames,
        picks: picks,
        target: target.value,
        revealed: revealed,
        revealing: revealing,
        onReveal: reveal,
        onNext: nextRound,
        lastRound: round == widget.roundCount,
        onExit: askExit,
      ),
    },
  );
}

// ─── TaskView ───────────────────────────────────────────────────────
class TaskView extends StatelessWidget {
  const TaskView({
    super.key,
    required this.round,
    required this.roundCount,
    required this.question,
    required this.target,
    required this.prompt,
    required this.onStart,
    required this.onExit,
  });
  final int round, roundCount;
  final Question question;
  final Target target;
  final String prompt;
  final VoidCallback onStart, onExit;
  @override
  Widget build(BuildContext context) => PageShell(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            RoundPill(text: 'Tur $round / $roundCount'),
            ExitIcon(onPressed: onExit),
          ],
        ),
        const SizedBox(height: 26),
        const Text(
          'GÖREV AÇIKLANDI',
          style: TextStyle(
            color: green,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          question.title,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 18),
        CardBox(
          child: Column(
            children: [
              Text(
                '${target.value}',
                style: const TextStyle(
                  color: green,
                  fontSize: 64,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'HEDEF TOPLAM',
                style: TextStyle(
                  color: muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                prompt,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  Chip(label: Text('${question.candidates.length} futbolcu')),
                  Chip(label: Text(target.difficulty)),
                  Chip(label: Text(question.unit)),
                ],
              ),
            ],
          ),
        ),
        const Spacer(),
        PrimaryButton(
          label: 'Görevi Anladım',
          icon: Icons.arrow_forward,
          onPressed: onStart,
        ),
      ],
    ),
  );
}

// ─── SelectionView ──────────────────────────────────────────────────
class SelectionView extends StatefulWidget {
  const SelectionView({
    super.key,
    required this.data,
    required this.question,
    required this.target,
    required this.prompt,
    required this.playerName,
    required this.playerIndex,
    required this.onLocked,
    required this.onExit,
  });
  final GameData data;
  final Question question;
  final Target target;
  final String prompt, playerName;
  final int playerIndex;
  final ValueChanged<List<Pick>> onLocked;
  final VoidCallback onExit;
  @override
  State<SelectionView> createState() => _SelectionViewState();
}

class _SelectionViewState extends State<SelectionView> {
  final search = TextEditingController();
  final selected = <Pick>[];
  late final List<Pick> initialSuggestions;
  Timer? timer;
  int secondsLeft = 90;
  bool submitted = false;
  @override
  void initState() {
    super.initState();
    final all = widget.question.candidates.map((id) {
      final player = widget.data.players[id]!;
      return Pick(player, widget.data.answers['${widget.question.id}:$id']!);
    }).toList();
    final ranked = [...all]..sort((a, b) => b.value.compareTo(a.value));
    final related = ranked.take(2).toList();
    final relatedIds = related.map((e) => e.player.id).toSet();
    final randomPool =
        all.where((e) => !relatedIds.contains(e.player.id)).toList()
          ..shuffle(Random());
    initialSuggestions = [...randomPool.take(5), ...related]..shuffle(Random());
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || submitted) return;
      if (secondsLeft <= 1) {
        gameStore.warning();
        setState(() => secondsLeft = 0);
        completeSelection();
      } else {
        if (secondsLeft <= 11) gameStore.countdown();
        setState(() => secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    search.dispose();
    super.dispose();
  }

  void completeSelection() {
    if (submitted) return;
    submitted = true;
    timer?.cancel();
    widget.onLocked([...selected]);
  }

  List<Pick> get results {
    final q = normalize(search.text);
    final selectedIds = selected.map((e) => e.player.id).toSet();
    if (q.isEmpty) {
      return initialSuggestions
          .where((e) => !selectedIds.contains(e.player.id))
          .toList();
    }
    final list = widget.question.candidates
        .where((id) => !selectedIds.contains(id))
        .map((id) {
          final p = widget.data.players[id]!;
          return Pick(p, widget.data.answers['${widget.question.id}:$id']!);
        })
        .where(
          (pick) =>
              [pick.player.name, ...pick.player.aliases, pick.player.team].any(
                (v) =>
                    normalize(v).contains(q) ||
                    normalize(v).split(' ').any((w) => w.startsWith(q)),
              ),
        )
        .toList();
    list.sort((a, b) => a.player.name.compareTo(b.player.name));
    return list.take(40).toList();
  }

  void add(Pick p) {
    if (selected.length == 5) return;
    gameStore.tap(GameSound.select);
    setState(() => selected.add(p));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: gameStore.activeThemeBgColor,
      automaticallyImplyLeading: false,
      title: Text('${widget.playerName} seçiyor'),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: RoundPill(text: formatTime(secondsLeft)),
        ),
        const SizedBox(width: 5),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: RoundPill(text: 'Hedef ${widget.target.value}'),
        ),
        ExitIcon(onPressed: widget.onExit),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: CardBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.question.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.prompt,
                    style: const TextStyle(color: muted, height: 1.35),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 68,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final p = i < selected.length ? selected[i] : null;
                return InkWell(
                  onTap: p == null
                      ? null
                      : () => setState(() => selected.removeAt(i)),
                  child: Container(
                    width: 62,
                    decoration: BoxDecoration(
                      color: p == null
                          ? gameStore.activeThemePanelColor
                          : gameStore.activeThemePanel2Color,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: p == null ? Colors.white12 : green,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        p == null ? '${i + 1}' : initials(p.player.name),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: p == null ? muted : green,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Futbolcu veya takım ara…',
                suffixText: '${selected.length}/5',
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: results.length,
              itemBuilder: (_, i) {
                final p = results[i];
                return Card(
                  color: gameStore.activeThemePanelColor,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: gameStore.activeThemePanel2Color,
                      child: const Text('⚽'),
                    ),
                    title: Text(
                      p.player.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${p.player.team} • ${positionName(p.player.position)}',
                    ),
                    trailing: const Icon(Icons.add_circle, color: green),
                    onTap: () => add(p),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: PrimaryButton(
              label: selected.length == 5
                  ? 'Seçimleri Kilitle'
                  : '${5 - selected.length} futbolcu daha seç',
              icon: Icons.lock,
              onPressed: selected.length == 5 ? completeSelection : null,
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── HandoffView ────────────────────────────────────────────────────
class HandoffView extends StatelessWidget {
  const HandoffView({
    super.key,
    required this.first,
    required this.second,
    required this.onReady,
    required this.onExit,
  });
  final String first, second;
  final VoidCallback onReady, onExit;
  @override
  Widget build(BuildContext context) => PageShell(
    child: Stack(
      children: [
        Positioned(top: 0, right: 0, child: ExitIcon(onPressed: onExit)),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded, color: green, size: 76),
              const SizedBox(height: 20),
              Text(
                '$first seçimini tamamladı.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Seçimler gizlendi. Telefonu şimdi $second adlı oyuncuya ver.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted, fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 34),
              PrimaryButton(
                label: 'Ben $second, hazırım',
                icon: Icons.arrow_forward,
                onPressed: onReady,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─── ReadyView ──────────────────────────────────────────────────────
class ReadyView extends StatelessWidget {
  const ReadyView({
    super.key,
    required this.names,
    required this.onOpen,
    required this.onExit,
  });
  final List<String> names;
  final VoidCallback onOpen, onExit;
  @override
  Widget build(BuildContext context) => PageShell(
    child: Stack(
      children: [
        Positioned(top: 0, right: 0, child: ExitIcon(onPressed: onExit)),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('⚽', style: TextStyle(fontSize: 68)),
              const SizedBox(height: 18),
              const Text(
                'Telefonu ortaya koyun.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              Text(
                '${names[0]}  VS  ${names[1]}',
                style: const TextStyle(
                  color: green,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 34),
              PrimaryButton(
                label: 'Sonuçları Aç',
                icon: Icons.auto_awesome,
                onPressed: onOpen,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─── RevealView ─────────────────────────────────────────────────────
class RevealView extends StatelessWidget {
  const RevealView({
    super.key,
    required this.names,
    required this.picks,
    required this.target,
    required this.revealed,
    required this.revealing,
    required this.onReveal,
    required this.onNext,
    required this.lastRound,
    required this.onExit,
  });
  final List<String> names;
  final List<List<Pick>> picks;
  final num target;
  final int revealed;
  final bool revealing, lastRound;
  final VoidCallback onReveal, onNext, onExit;
  num partial(int side) {
    num total = 0;
    for (var i = 0; i < 5; i++) {
      final order = i * 2 + side + 1;
      if (revealed >= order) total += picks[side][i].value;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: gameStore.activeThemeBgColor,
      automaticallyImplyLeading: false,
      title: const Text('Kartlar Açılıyor'),
      actions: [ExitIcon(onPressed: onExit)],
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ScoreBox(name: names[0], value: partial(0)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      const Text(
                        'HEDEF',
                        style: TextStyle(color: muted, fontSize: 10),
                      ),
                      Text(
                        '$target',
                        style: const TextStyle(
                          color: green,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ScoreBox(name: names[1], value: partial(1)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.separated(
                itemCount: 5,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => Row(
                  children: [
                    Expanded(
                      child: RevealCard(
                        pick: picks[0][i],
                        open: revealed >= i * 2 + 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(color: muted),
                      ),
                    ),
                    Expanded(
                      child: RevealCard(
                        pick: picks[1][i],
                        open: revealed >= i * 2 + 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (revealed < 10)
              PrimaryButton(
                label: revealing ? 'Kartlar açılıyor…' : 'Kartları Tek Tek Aç',
                icon: Icons.visibility,
                onPressed: revealing ? null : onReveal,
              )
            else
              PrimaryButton(
                label: lastRound ? 'Maçı Bitir' : 'Sonraki Tura Geç',
                icon: Icons.arrow_forward,
                onPressed: onNext,
              ),
          ],
        ),
      ),
    ),
  );
}

// ─── RevealCard ─────────────────────────────────────────────────────
class RevealCard extends StatelessWidget {
  const RevealCard({super.key, required this.pick, required this.open});
  final Pick pick;
  final bool open;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 350),
    height: 66,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: open
          ? gameStore.activeThemePanel2Color
          : gameStore.activeThemePanelColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: open ? green : Colors.white12),
    ),
    child: open
        ? Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      pick.player.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      pick.player.team,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: muted, fontSize: 9),
                    ),
                  ],
                ),
              ),
              Text(
                '${pick.value}',
                style: const TextStyle(
                  color: green,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          )
        : const Center(
            child: Text(
              '?',
              style: TextStyle(
                color: green,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
  );
}

// ─── WinnerDialog ───────────────────────────────────────────────────
class WinnerDialog extends StatelessWidget {
  const WinnerDialog({
    super.key,
    required this.names,
    required this.totals,
    required this.target,
    required this.winner,
  });
  final List<String> names;
  final List<num> totals;
  final num target;
  final int? winner;
  @override
  Widget build(BuildContext context) {
    final perfect = totals.any((value) => value == target);
    return AlertDialog(
      backgroundColor: perfect
          ? const Color(0xFF3A2805)
          : gameStore.activeThemePanel2Color,
      icon: Text(
        perfect
            ? '🎯'
            : winner == null
            ? '🤝'
            : '🏆',
        style: const TextStyle(fontSize: 58),
      ),
      title: Text(
        perfect
            ? 'Tam isabet!'
            : winner == null
            ? 'Berabere!'
            : '${names[winner!]} kazandı!',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: perfect ? const Color(0xFFFFD166) : Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: Text(
        '${names[0]}: ${totals[0]}   •   Hedef: $target   •   ${names[1]}: ${totals[1]}',
        textAlign: TextAlign.center,
      ),
      actions: [
        PrimaryButton(
          label: 'Sonuç Tablosunu Gör',
          icon: Icons.arrow_forward,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

// ─── MatchEndDialog ─────────────────────────────────────────────────
class MatchEndDialog extends StatelessWidget {
  const MatchEndDialog({
    super.key,
    required this.names,
    required this.score,
    required this.winner,
    required this.close,
  });
  final List<String> names;
  final List<int> score;
  final int? winner;
  final VoidCallback close;
  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: gameStore.activeThemePanel2Color,
    icon: const Text('🏆', style: TextStyle(fontSize: 58)),
    title: Text(
      winner == null ? 'Maç berabere!' : 'Meydanın kazananı ${names[winner!]}!',
      textAlign: TextAlign.center,
    ),
    content: Text(
      '${names[0]} ${score[0]} — ${score[1]} ${names[1]}',
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
    ),
    actions: [
      PrimaryButton(
        label: 'Ana Ekrana Dön',
        icon: Icons.home,
        onPressed: close,
      ),
    ],
  );
}

// ─── WinnerCelebration ──────────────────────────────────────────────
class WinnerCelebration extends StatefulWidget {
  const WinnerCelebration({
    super.key,
    required this.winnerName,
    required this.draw,
    this.perfect = false,
  });
  final String winnerName;
  final bool draw, perfect;
  @override
  State<WinnerCelebration> createState() => _WinnerCelebrationState();
}

class _WinnerCelebrationState extends State<WinnerCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) {
        final fade = controller.value < .72
            ? 1.0
            : (1 - controller.value) / .28;
        final entrance = Curves.elasticOut.transform(
          min(1.0, controller.value * 4),
        );
        return Opacity(
          opacity: fade.clamp(0.0, 1.0).toDouble(),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: ConfettiPainter(
                    controller.value,
                    golden: widget.perfect,
                  ),
                ),
              ),
              Transform.scale(
                scale: entrance,
                child: Container(
                  width: min(screenWidth * .78, 350.0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 22,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: widget.perfect
                          ? const [Color(0xFF6A4700), Color(0xFF1E1200)]
                          : const [Color(0xFF164D35), Color(0xFF071C13)],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: widget.perfect ? const Color(0xFFFFD166) : green,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.perfect
                            ? const Color(0x88FFD166)
                            : const Color(0xAA000000),
                        blurRadius: 45,
                        spreadRadius: 12,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.perfect
                            ? '🎯'
                            : widget.draw
                            ? '🤝'
                            : '🏆',
                        style: const TextStyle(fontSize: 58),
                      ),
                      Text(
                        widget.perfect
                            ? 'TAM İSABET!'
                            : widget.draw
                            ? 'MEYDAN BERABERE'
                            : 'MEYDANIN KAZANANI',
                        style: TextStyle(
                          color: widget.perfect
                              ? const Color(0xFFFFD166)
                              : green,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        widget.winnerName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 31,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── ConfettiPainter ────────────────────────────────────────────────
class ConfettiPainter extends CustomPainter {
  ConfettiPainter(this.progress, {this.golden = false});
  final double progress;
  final bool golden;
  static const colors = [
    green,
    Color(0xFFFFD166),
    Color(0xFF5EC8FF),
    Color(0xFFFF6685),
    Colors.white,
  ];
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 72; i++) {
      final seed = (i * 37 % 101) / 101;
      final x =
          ((seed * size.width) + sin(progress * 10 + i) * 24) % size.width;
      final y =
          ((progress * 1.45 + (i * 29 % 97) / 97) % 1.15) * size.height - 30;
      final paint = Paint()
        ..color = golden
            ? const [Color(0xFFFFD166), Color(0xFFFFF0A8), Colors.white][i % 3]
            : colors[i % colors.length];
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * 8 + i);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: (5 + i % 5).toDouble(),
            height: (11 + i % 7).toDouble(),
          ),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.golden != golden;
}
