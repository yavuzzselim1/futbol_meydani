import 'dart:ui' as dart_ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:futbol_meydani/constants.dart';
import 'package:futbol_meydani/globals.dart';
import 'package:futbol_meydani/models/game_data.dart';

class AppBackground extends StatefulWidget {
  const AppBackground({super.key, required this.child, this.imagePath});
  final Widget child;
  final String? imagePath;

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _scaleAnimation = Tween<double>(begin: 1.15, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(color: bg),
    child: Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              );
            },
            child: Image.asset(
              widget.imagePath ?? 'assets/main/pro_football_bg_v2.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.7),
                  Colors.black.withValues(alpha: 0.1),
                  Colors.black.withValues(alpha: 0.8),
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
        ),
        widget.child,
      ],
    ),
  );
}

// ─── PageShell ──────────────────────────────────────────────────────
class PageShell extends StatelessWidget {
  const PageShell({super.key, required this.child, this.bottomSafeArea = true});
  final Widget child;
  final bool bottomSafeArea;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: AppBackground(
      child: SafeArea(
        bottom: bottomSafeArea,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, bottomSafeArea ? 24 : 0),
          child: child,
        ),
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

// ─── GlassCard ──────────────────────────────────────────────────────
class GlassCard extends StatelessWidget {
  final Widget child;
  final Key? cardKey;
  
  const GlassCard({super.key, required this.child, this.cardKey});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: cardKey,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: dart_ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
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
      ),
    );
  }
}

// ─── PremiumButton ──────────────────────────────────────────────────
class PremiumButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isDanger;
  
  const PremiumButton({
    super.key,
    required this.label, 
    required this.icon, 
    this.onPressed, 
    this.isDanger = false
  });

  @override
  State<PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<PremiumButton> {
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
                  ? [const Color(0xFFFF6B5F).withValues(alpha: 0.1), const Color(0xFFD63B30).withValues(alpha: 0.2)]
                  : [Colors.black.withValues(alpha: 0.8), Colors.black.withValues(alpha: 0.6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: widget.isDanger 
                  ? const Color(0xFFFF6B5F).withValues(alpha: 0.5)
                  : const Color(0xFF00E676).withValues(alpha: 0.8),
              width: 1.5,
            ),
            boxShadow: [
              if (!_isPressed)
                BoxShadow(
                  color: (widget.isDanger ? const Color(0xFFFF6B5F) : const Color(0xFF00E676)).withValues(alpha: 0.25), 
                  blurRadius: 16,
                  spreadRadius: -4,
                  offset: const Offset(0, 0)
                ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon, 
                color: widget.isDanger ? const Color(0xFFFFB3AD) : const Color(0xFF00E676), 
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.isDanger ? Colors.white : Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showCoinBurstOverlay(BuildContext context, {Offset? origin, Offset? target, VoidCallback? onCoinArrived}) {
  final overlay = Overlay.of(context);
  OverlayEntry? entry;
  entry = OverlayEntry(
    builder: (context) => CoinScatterAnimation(
      origin: origin,
      target: target,
      onCoinArrived: onCoinArrived,
      onComplete: () {
        entry?.remove();
      },
    ),
  );
  overlay.insert(entry);
}

class CoinScatterAnimation extends StatefulWidget {
  final Offset? origin;
  final Offset? target;
  final VoidCallback onComplete;
  final VoidCallback? onCoinArrived;

  const CoinScatterAnimation({super.key, this.origin, this.target, required this.onComplete, this.onCoinArrived});

  @override
  State<CoinScatterAnimation> createState() => _CoinScatterAnimationState();
}

class _CoinScatterAnimationState extends State<CoinScatterAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final int coinCount = 20; // Reduced count for cleaner sequential effect
  final List<_CoinParticle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
    
    for (int i = 0; i < coinCount; i++) {
      // Angles pointing downwards (between 0.2 rad and PI - 0.2 rad)
      final angle = math.pi * 0.1 + _random.nextDouble() * math.pi * 0.8;
      final speed = _random.nextDouble() * 200 + 100; // reduced speed for less scatter
      final flyDelay = _random.nextDouble() * 0.4; // staggered fly start
      
      _particles.add(_CoinParticle(
        angle: angle,
        speed: speed,
        size: _random.nextDouble() * 12 + 16, // slightly smaller coins
        rotationSpeed: _random.nextDouble() * 4 - 2,
        flyDelay: flyDelay,
      ));

      if (widget.target != null && widget.onCoinArrived != null) {
        final flyEnd = 0.3 + flyDelay + 0.3;
        Future.delayed(Duration(milliseconds: (2000 * flyEnd).toInt()), () {
          if (mounted) widget.onCoinArrived!();
        });
      }
    }

    _controller.forward().then((_) {
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final globalProgress = _controller.value;
          
          return Stack(
            children: _particles.map((p) {
              final startX = widget.origin?.dx ?? MediaQuery.of(context).size.width / 2;
              final startY = widget.origin?.dy ?? MediaQuery.of(context).size.height / 2;
              
              double currentX;
              double currentY;
              double opacity = 1.0;
              double scale = 1.0;
              
              if (widget.target != null) {
                // Flying to target mode
                final flyStart = 0.3 + p.flyDelay;
                final flyEnd = flyStart + 0.3;
                
                if (globalProgress < flyStart) {
                  // Burst phase
                  final burstProgress = globalProgress / flyStart;
                  final easeOut = Curves.easeOutCubic.transform(burstProgress);
                  currentX = startX + math.cos(p.angle) * p.speed * 0.5 * easeOut;
                  currentY = startY + math.sin(p.angle) * p.speed * 0.5 * easeOut + (easeOut * easeOut * 100);
                } else if (globalProgress < flyEnd) {
                  // Fly phase
                  final burstProgress = 1.0;
                  final easeOut = Curves.easeOutCubic.transform(burstProgress);
                  final burstX = startX + math.cos(p.angle) * p.speed * 0.5 * easeOut;
                  final burstY = startY + math.sin(p.angle) * p.speed * 0.5 * easeOut + (easeOut * easeOut * 100);
                  
                  final flyProgress = (globalProgress - flyStart) / (flyEnd - flyStart);
                  final easeIn = Curves.easeInCubic.transform(flyProgress);
                  
                  currentX = dart_ui.lerpDouble(burstX, widget.target!.dx, easeIn)!;
                  currentY = dart_ui.lerpDouble(burstY, widget.target!.dy, easeIn)!;
                  scale = dart_ui.lerpDouble(1.0, 0.5, easeIn)!;
                } else {
                  // Reached target
                  currentX = widget.target!.dx;
                  currentY = widget.target!.dy;
                  opacity = 0.0;
                }
              } else {
                // Gravity only mode
                opacity = globalProgress > 0.7 ? (1.0 - globalProgress) / 0.3 : 1.0;
                currentX = startX + math.cos(p.angle) * p.speed * globalProgress;
                currentY = startY + math.sin(p.angle) * p.speed * globalProgress + (globalProgress * globalProgress * 800);
              }

              return Positioned(
                left: currentX - p.size / 2,
                top: currentY - p.size / 2,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: Transform.rotate(
                      angle: globalProgress * 15 * p.rotationSpeed,
                      child: Icon(Icons.monetization_on_rounded, color: const Color(0xFF00E676), size: p.size),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _CoinParticle {
  final double angle;
  final double speed;
  final double size;
  final double rotationSpeed;
  final double flyDelay;

  _CoinParticle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.rotationSpeed,
    this.flyDelay = 0.0,
  });
}
