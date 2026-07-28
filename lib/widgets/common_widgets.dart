import 'package:flutter/material.dart';
import 'package:futbol_meydani/constants.dart';
import 'package:futbol_meydani/globals.dart';
import 'package:futbol_meydani/models/game_data.dart';

// ─── AppBackground ──────────────────────────────────────────────────
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(-.8, -.9),
        radius: 1.5,
        colors: [Color(0xFF153B2E), bg],
      ),
    ),
    child: child,
  );
}

// ─── PageShell ──────────────────────────────────────────────────────
class PageShell extends StatelessWidget {
  const PageShell({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: AppBackground(
      child: SafeArea(
        child: Padding(padding: const EdgeInsets.all(24), child: child),
      ),
    ),
  );
}

// ─── Brand ──────────────────────────────────────────────────────────
class Brand extends StatelessWidget {
  const Brand({super.key});
  @override
  Widget build(BuildContext context) => Hero(
    tag: 'app_logo',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        'assets/branding/app_icon.png',
        width: 42,
        height: 42,
        fit: BoxFit.cover,
      ),
    ),
  );
}

// ─── CardBox ────────────────────────────────────────────────────────
class CardBox extends StatelessWidget {
  const CardBox({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: panel,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white12),
    ),
    child: child,
  );
}

// ─── RoundPill ──────────────────────────────────────────────────────
class RoundPill extends StatelessWidget {
  const RoundPill({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: green.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: green.withValues(alpha: .4)),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: green,
        fontWeight: FontWeight.w900,
        fontSize: 12,
      ),
    ),
  );
}

// ─── ScoreBox ───────────────────────────────────────────────────────
class ScoreBox extends StatelessWidget {
  const ScoreBox({super.key, required this.name, required this.value});
  final String name;
  final num value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: panel,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white12),
    ),
    child: Column(
      children: [
        Text(
          name,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
        Text(
          '$value',
          style: const TextStyle(
            color: green,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

// ─── PrimaryButton ──────────────────────────────────────────────────
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: onPressed == null
          ? null
          : () {
              gameStore.tap();
              onPressed!();
            },
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      style: FilledButton.styleFrom(
        backgroundColor: green,
        foregroundColor: bg,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    ),
  );
}

// ─── ExitIcon ───────────────────────────────────────────────────────
class ExitIcon extends StatelessWidget {
  const ExitIcon({super.key, required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => IconButton(
    icon: const Icon(Icons.close_rounded),
    tooltip: 'Çık',
    onPressed: () {
      gameStore.tap(GameSound.exit);
      onPressed();
    },
  );
}

// ─── ErrorView ──────────────────────────────────────────────────────
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF6B5F), size: 56),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, height: 1.5),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 18),
            PrimaryButton(
              label: 'Tekrar Dene',
              icon: Icons.refresh,
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    ),
  );
}

// ─── ProfileStat ────────────────────────────────────────────────────
class ProfileStat extends StatelessWidget {
  const ProfileStat({super.key, required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Container(
    height: 82,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: panel,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: Colors.white10),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          maxLines: 1,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: muted,
            fontSize: 8,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

// ─── RevealSpotlight ────────────────────────────────────────────────
class RevealSpotlight extends StatelessWidget {
  const RevealSpotlight({
    super.key,
    required this.name,
    required this.pick,
    required this.unit,
    required this.showValue,
  });
  final String name, unit;
  final Pick pick;
  final bool showValue;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: 1,
    duration: const Duration(milliseconds: 220),
    child: Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFA061811),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: green, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x8871F39A), blurRadius: 32)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: const TextStyle(
              color: green,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            pick.player.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          Text(
            pick.player.team,
            style: const TextStyle(color: muted, fontSize: 11),
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: showValue
                ? Text(
                    '${pick.value} $unit',
                    key: const ValueKey('value'),
                    style: const TextStyle(
                      color: green,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : const Text(
                    '?',
                    key: ValueKey('hidden'),
                    style: TextStyle(
                      color: green,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}

// ─── HowToRow ───────────────────────────────────────────────────────
class HowToRow extends StatelessWidget {
  const HowToRow({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, color: green, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(color: muted, height: 1.4)),
        ),
      ],
    ),
  );
}

// ─── OnlinePlayerTile ───────────────────────────────────────────────
class OnlinePlayerTile extends StatelessWidget {
  const OnlinePlayerTile({
    super.key,
    required this.name,
    required this.isReady,
    required this.isConnected,
  });
  final String name;
  final bool isReady, isConnected;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: panel,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: isReady ? green : Colors.white12),
    ),
    child: Row(
      children: [
        Icon(
          isConnected ? Icons.person_rounded : Icons.person_off_outlined,
          color: isConnected ? green : muted,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        if (isReady)
          const Icon(Icons.check_circle_rounded, color: green)
        else
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    ),
  );
}
