import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/progress_merge.dart';

Future<ProgressMergeDecision?> showOfflineProgressMergeDialog(
  BuildContext context,
  ProgressMergePreview preview,
) {
  return showDialog<ProgressMergeDecision>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _OfflineProgressMergeDialog(preview: preview),
  );
}

class _OfflineProgressMergeDialog extends StatelessWidget {
  const _OfflineProgressMergeDialog({required this.preview});

  final ProgressMergePreview preview;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF63F59A);
    const panel = Color(0xFF0B2018);
    const muted = Color(0xFFAFC4B6);

    return AlertDialog(
      backgroundColor: panel,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: green.withValues(alpha: 0.45)),
      ),
      titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
      contentPadding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
      actionsPadding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: green.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cloud_sync_rounded, color: green, size: 27),
          ),
          const SizedBox(height: 14),
          Text(
            'Çevrimdışı ilerleme bulundu',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cihazındaki ilerlemeyi hesabınla birleştirebiliriz. '
              'Yüksek değerler ve açılmış ödüller korunur.',
              style: GoogleFonts.inter(
                color: muted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _ProgressColumn(
                    title: 'BU CİHAZ',
                    snapshot: preview.local,
                    color: green,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ProgressColumn(
                    title: 'BULUT',
                    snapshot: preview.cloud,
                    color: const Color(0xFF5EC8FF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield_outlined, color: green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kupa, çevrimiçi galibiyet ve mağlubiyetler yalnızca '
                      'sunucudan alınır. Değerler birbirine eklenmez.',
                      style: GoogleFonts.inter(
                        color: muted,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () =>
                Navigator.pop(context, ProgressMergeDecision.merge),
            style: FilledButton.styleFrom(
              backgroundColor: green,
              foregroundColor: const Color(0xFF04110C),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            icon: const Icon(Icons.merge_rounded),
            label: const Text(
              'İLERLEMEYİ BİRLEŞTİR',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () =>
                Navigator.pop(context, ProgressMergeDecision.useCloud),
            child: const Text(
              'YALNIZCA BULUTTAKİ VERİYİ KULLAN',
              style: TextStyle(
                color: muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressColumn extends StatelessWidget {
  const _ProgressColumn({
    required this.title,
    required this.snapshot,
    required this.color,
  });

  final String title;
  final ProgressSnapshot snapshot;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          _Metric(label: 'Etap', value: '${snapshot.careerStage}/12'),
          _Metric(label: 'Yıldız', value: '${snapshot.careerStars}/36'),
          _Metric(label: 'En iyi', value: '${snapshot.lastMinuteBest}'),
          _Metric(label: 'XP', value: '${snapshot.xp}'),
          _Metric(label: 'MP', value: '${snapshot.coins}'),
          _Metric(
            label: 'Ödül',
            value:
                '${snapshot.unlockedAvatars.length + snapshot.unlockedThemes.length + snapshot.unlockedBadges.length}',
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFFAFC4B6), fontSize: 11),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
