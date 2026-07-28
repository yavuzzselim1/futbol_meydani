import 'dart:math';

import 'package:flutter/material.dart';
import 'package:futbol_meydani/constants.dart';
import 'package:futbol_meydani/models/game_data.dart';
import 'package:futbol_meydani/utils/helpers.dart';

// ─── SquadPitch ─────────────────────────────────────────────────────
class SquadPitch extends StatelessWidget {
  const SquadPitch({
    super.key,
    required this.formation,
    required this.picks,
    this.onRemove,
    this.onDrop,
    this.height = 245,
    this.revealCount = 99,
    this.showValues = false,
    this.compact = false,
  });

  final Formation formation;
  final List<Pick> picks;
  final ValueChanged<Pick>? onRemove;
  final ValueChanged<Pick>? onDrop;
  final double? height;
  final int revealCount;
  final bool showValues;
  final bool compact;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final pitchWidth = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : MediaQuery.sizeOf(context).width;
      return Container(
        height: height,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1D6945), Color(0xFF0F492F)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x8871F39A)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: SquadPitchPainter())),
              ...buildPosition('GK', formation.gk, .84, 0, pitchWidth),
              ...buildPosition(
                'DF',
                formation.df,
                .61,
                formation.gk,
                pitchWidth,
              ),
              ...buildPosition(
                'MF',
                formation.mf,
                .37,
                formation.gk + formation.df,
                pitchWidth,
              ),
              ...buildPosition(
                'FW',
                formation.fw,
                .12,
                formation.gk + formation.df + formation.mf,
                pitchWidth,
              ),
            ],
          ),
        ),
      );
    },
  );

  List<Widget> buildPosition(
    String position,
    int quota,
    double y,
    int offset,
    double pitchWidth,
  ) {
    final players = picks.where((e) => e.player.position == position).toList();
    final slotSpacing = pitchWidth / (quota + 1);
    final preferredCardWidth = (slotSpacing * .82)
        .clamp(compact ? 30.0 : 54.0, compact ? 68.0 : 96.0)
        .toDouble();
    final minimumGap = compact ? 7.0 : 12.0;
    final spreadSpacing = quota <= 1
        ? pitchWidth
        : pitchWidth * .72 / (quota - 1);
    final maximumCardWidth = max(24.0, spreadSpacing - minimumGap);
    final cardWidth = preferredCardWidth
        .clamp(24.0, maximumCardWidth)
        .toDouble();
    final nameSize = (cardWidth / (compact ? 6.2 : 9.2))
        .clamp(compact ? 7.5 : 9.0, compact ? 10.5 : 11.5)
        .toDouble();
    return List.generate(quota, (index) {
      final pick = index < players.length ? players[index] : null;
      final x = quota == 1 ? .5 : .14 + (.72 * index / (quota - 1));
      final revealed = offset + index < revealCount;
      final label = !revealed && showValues
          ? '?'
          : pick?.player.name ??
                (showValues ? 'Seçilmedi' : positionName(position));
      return Align(
        alignment: Alignment(x * 2 - 1, y * 2 - 1),
        child: DragTarget<Pick>(
          onWillAcceptWithDetails: (details) =>
              onDrop != null &&
              pick == null &&
              details.data.player.position == position,
          onAcceptWithDetails: (details) => onDrop?.call(details.data),
          builder: (context, candidates, rejects) {
            final invalid = rejects.isNotEmpty;
            return GestureDetector(
              onTap: pick == null || onRemove == null
                  ? null
                  : () => onRemove!(pick),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: cardWidth,
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 4 : 7,
                      vertical: compact ? 5 : 7,
                    ),
                    decoration: BoxDecoration(
                      color: invalid
                          ? const Color(0xDD57151B)
                          : candidates.isNotEmpty
                          ? const Color(0xFF225C3E)
                          : pick == null
                          ? const Color(0xAA082D1D)
                          : const Color(0xEE071D13),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: invalid
                            ? Colors.redAccent
                            : candidates.isNotEmpty || pick != null
                            ? green
                            : Colors.white24,
                        width: invalid || candidates.isNotEmpty ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          positionIcon(position),
                          size: compact ? nameSize + 2 : nameSize + 4,
                          color: pick == null ? muted : green,
                        ),
                        Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: nameSize,
                            height: 1.02,
                            fontWeight: FontWeight.w900,
                            color: pick == null ? muted : Colors.white,
                          ),
                        ),
                        if (showValues && revealed)
                          Text(
                            '${pick?.value ?? 0}',
                            style: TextStyle(
                              color: green,
                              fontSize: nameSize + 2,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (invalid)
                    const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 27,
                      shadows: [Shadow(color: Colors.red, blurRadius: 8)],
                    ),
                ],
              ),
            );
          },
        ),
      );
    });
  }
}

// ─── SquadPitchPainter ──────────────────────────────────────────────
class SquadPitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stripe = Paint()..color = const Color(0x0DFFFFFF);
    final stripeHeight = size.height / 8;
    for (var i = 0; i < 8; i += 2) {
      canvas.drawRect(
        Rect.fromLTWH(0, i * stripeHeight, size.width, stripeHeight),
        stripe,
      );
    }
    final p = Paint()
      ..color = const Color(0x55FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(Rect.fromLTWH(8, 8, size.width - 16, size.height - 16), p);
    canvas.drawLine(
      Offset(8, size.height / 2),
      Offset(size.width - 8, size.height / 2),
      p,
    );
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 25, p);
    canvas.drawRect(Rect.fromLTWH(size.width / 2 - 48, 8, 96, 30), p);
    canvas.drawRect(
      Rect.fromLTWH(size.width / 2 - 48, size.height - 38, 96, 30),
      p,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      2,
      Paint()..color = const Color(0x88FFFFFF),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── ResultPitchCard ────────────────────────────────────────────────
class ResultPitchCard extends StatelessWidget {
  const ResultPitchCard({
    super.key,
    required this.name,
    required this.total,
    required this.difference,
    required this.formation,
    required this.picks,
  });

  final String name;
  final num total, difference;
  final Formation formation;
  final List<Pick> picks;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: panel,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white12),
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            Text(
              'Toplam $total • Fark $difference',
              style: const TextStyle(
                color: green,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SquadPitch(formation: formation, picks: picks, height: 190),
      ],
    ),
  );
}
