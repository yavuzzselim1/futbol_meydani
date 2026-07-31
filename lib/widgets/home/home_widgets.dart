import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:futbol_meydani/utils/glass_toast.dart';
import 'package:video_player/video_player.dart';

import '../../globals.dart';
import '../../constants.dart';
import '../../models/game_data.dart';
import '../../online/supabase_online_game.dart';

import '../../widgets/last_minute/last_minute_career_screen.dart';
import '../../widgets/online/online_entry_screen.dart';
import '../../widgets/online/online_profile_screen.dart';

import '../../screens/setup_screen.dart';
import '../../screens/squad_challenge_screen.dart';
import '../../screens/profile_screen.dart';
import '../../screens/daily_challenge_screen.dart';
import '../../screens/settings_screen.dart';

import '../../services/supabase_state.dart';

class AppDrawerWrapper extends StatefulWidget {
  const AppDrawerWrapper({
    super.key,
    required this.child,
    required this.drawer,
  });
  final Widget child;
  final Widget drawer;

  static AppDrawerWrapperState? of(BuildContext context) =>
      context.findAncestorStateOfType<AppDrawerWrapperState>();

  @override
  State<AppDrawerWrapper> createState() => AppDrawerWrapperState();
}

class AppDrawerWrapperState extends State<AppDrawerWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  void toggle() =>
      _controller.isDismissed ? _controller.forward() : _controller.reverse();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slideAmount =
        MediaQuery.of(context).size.width * 0.85; // Increased from 0.70 to 0.85

    return Scaffold(
      body: Container(
        color: Colors.black,
        child: GestureDetector(
          onHorizontalDragUpdate: (details) {
            _controller.value += details.primaryDelta! / slideAmount;
          },
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity! > 300) {
              _controller.forward();
            } else if (details.primaryVelocity! < -300) {
              _controller.reverse();
            } else if (_controller.value > 0.5) {
              _controller.forward();
            } else {
              _controller.reverse();
            }
          },
          child: Stack(
            children: [
              // Sidebar layer
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: slideAmount,
                child: widget.drawer,
              ),
              // Main screen layer
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  final slide = _animation.value * slideAmount;
                  return Transform.translate(
                    offset: Offset(slide, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          _animation.value * 32,
                        ),
                        boxShadow: [
                          if (_controller.value > 0.01)
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: 0.5 * _animation.value,
                              ),
                              blurRadius: 30,
                              spreadRadius: 5,
                              offset: const Offset(-10, 0),
                            ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          _animation.value * 32,
                        ),
                        child: Stack(
                          children: [
                            IgnorePointer(
                              ignoring: _controller.value > 0.3,
                              child: child!,
                            ),
                            // Invisible overlay to catch taps when drawer is open
                            if (_controller.value > 0.01)
                              Positioned.fill(
                                child: GestureDetector(
                                  onTap: toggle,
                                  behavior: HitTestBehavior.opaque,
                                  child: const SizedBox.expand(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                child: widget.child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeAtmosphere extends StatelessWidget {
  const HomeAtmosphere({super.key});
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0A2218), Color(0xFF04100B), Color(0xFF020705)],
        stops: [0.0, 0.45, 1.0],
      ),
    ),
    child: CustomPaint(painter: HomeAtmospherePainter()),
  );
}

class HomeAtmospherePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Top Emerald Glow
    final glowShader = const RadialGradient(
      center: Alignment(0.0, -0.9),
      radius: 0.85,
      colors: [Color(0x281EE062), Color(0x00000000)],
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..shader = glowShader);

    // Subtle Tech Grid
    final gridPaint = Paint()
      ..color = const Color(0x0D1EE062)
      ..strokeWidth = 1.0;
    const gridStep = 40.0;
    for (double x = 0; x < size.width; x += gridStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Bottom Vignette
    final vignette = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Color(0xDD020705)],
        stops: [0.6, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MenuSidebar extends StatelessWidget {
  const MenuSidebar({
    super.key,
    required this.data,
    required this.onShowHowToPlay,
  });
  final GameData data;
  final VoidCallback onShowHowToPlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF05120A),
            Colors.black,
            Color(0xFF091C12),
          ], // Premium dark background
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [green, Color(0xFF11998E)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: green.withValues(alpha: 0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.black,
                      child: Icon(Icons.person_rounded, color: green, size: 30),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Oyuncu',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: green.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            'Seviye 1 • ${gameStore.matches} Maç',
                            style: const TextStyle(
                              fontSize: 11,
                              color: green,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  24 + MediaQuery.of(context).padding.bottom,
                ),
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 12),
                    child: Text(
                      'KARİYER & İSTATİSTİK',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  _SidebarItem(
                    icon: Icons.person_rounded,
                    title: 'Meydan Profili',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    ),
                  ),
                  _SidebarItem(
                    icon: Icons.emoji_events_rounded,
                    title: 'Görevler & Başarımlar',
                    onTap: () {
                      AppDrawerWrapper.of(context)?.toggle();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DailyChallengeScreen(data: data),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 12),
                    child: Text(
                      'SOSYAL & ÇEVRİMİÇİ',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  _SidebarItem(
                    icon: Icons.public_rounded,
                    title: 'Çevrimiçi Profil',
                    onTap: () {
                      final client = SupabaseState.client;

                      if (client != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OnlineProfileScreen(
                              repository: SupabaseOnlineGameRepository(client),
                            ),
                          ),
                        );
                      } else {
                        GlassToast.show(context, 'Çevrimiçi profil geçici olarak kullanılamıyor.', isError: true);
                      }
                    },
                  ),
                  _SidebarItem(
                    icon: Icons.leaderboard_rounded,
                    title: 'Liderlik Tablosu',
                    badge: 'YAKINDA',
                    onTap: () {
                      GlassToast.show(context, 'Liderlik tablosu çok yakında eklenecek!', isError: false);
                    },
                  ),
                  const SizedBox(height: 24),

                  const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 12),
                    child: Text(
                      'DESTEK & OYUN',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  _SidebarItem(
                    icon: Icons.explore_rounded,
                    title: 'Nasıl Oynanır?',
                    onTap: () {
                      AppDrawerWrapper.of(context)?.toggle();
                      onShowHowToPlay();
                    },
                  ),
                  _SidebarItem(
                    icon: Icons.settings_rounded,
                    title: 'Ayarlar',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.title,
    this.badge,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Material(
        color: Colors.white.withValues(
          alpha: 0.03,
        ), // Subtle premium dark background
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            gameStore.tap(GameSound.select);
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          splashColor: green.withValues(alpha: 0.15),
          highlightColor: green.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    margin: const EdgeInsets.only(left: 8, right: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD166).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFFFD166).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Color(0xFFFFD166),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white30,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key, required this.data});
  final GameData data;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020705),
      body: Stack(
        children: [
          // Background
          const Positioned.fill(child: HomeAtmosphere()),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          gameStore.tap();
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'MEYDAN SEÇ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // Modes List
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildModeCard(
                        context: context,
                        title: 'SON DAKİKA',
                        description:
                            'Yapay zekaya karşı tek oyunculu kariyer modu.',
                        tag: 'ÇEVRİMDIŞI',
                        icon: Icons.bolt_rounded,
                        accentColor: const Color(0xFFFF4444),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LastMinuteCareerScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildModeCard(
                        context: context,
                        title: 'KARŞILIKLI MEYDAN',
                        description:
                            'Aynı telefonda karşılıklı iki kişi oynayın.',
                        tag: 'AYNI TELEFON',
                        icon: Icons.people_alt_rounded,
                        accentColor: const Color(0xFF1EE062),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SetupScreen(data: data),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildModeCard(
                        context: context,
                        title: 'MEYDAN KADROSU',
                        description:
                            'Kendi kadronu kur ve arkadaşlarınla takım ol.',
                        tag: 'AYNI TELEFON',
                        icon: Icons.groups_2_rounded,
                        accentColor: const Color(0xFFFFD166),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SquadSetupScreen(data: data),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildModeCard(
                        context: context,
                        title: 'ONLINE MEYDAN',
                        description:
                            'Dünya çapındaki oyuncularla çevrimiçi rekabet et.',
                        tag: 'ÇEVRİMİÇİ',
                        icon: Icons.public_rounded,
                        accentColor: const Color(0xFF5EC8FF),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OnlineEntryScreen(data: data),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required BuildContext context,
    required String title,
    required String description,
    required String tag,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        gameStore.tap();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0A140F),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: accentColor, size: 36),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.2),
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}

class VideoBackground extends StatefulWidget {
  final String videoPath;
  const VideoBackground({super.key, required this.videoPath});

  @override
  State<VideoBackground> createState() => _VideoBackgroundState();
}

bool _hasPlayedGlobal = false;

class _VideoBackgroundState extends State<VideoBackground>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isVideoFinished = false;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scaleAnimation = Tween<double>(begin: 1.15, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );

    if (_hasPlayedGlobal) {
      _isVideoFinished = true;
      _fadeController.forward(from: 0.0);
    } else {
      _controller = VideoPlayerController.asset(widget.videoPath)
        ..initialize().then((_) {
          _controller?.setVolume(0.0);
          _controller?.play();
          setState(() {});
        });

      _controller?.addListener(() {
        if (!_isVideoFinished &&
            _controller != null &&
            _controller!.value.position >= const Duration(milliseconds: 5300)) {
          setState(() {
            _isVideoFinished = true;
          });
          _hasPlayedGlobal = true;
          _controller?.pause();
          _fadeController.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasPlayedGlobal) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black),
          AnimatedBuilder(
            animation: _fadeController,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeController.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Image.asset(
                    'assets/main/5.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                ),
              );
            },
          ),
        ],
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return Container(color: Colors.black);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        // The Video
        SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          ),
        ),
        // The Transitioning Image
        if (_isVideoFinished || _fadeController.value > 0)
          AnimatedBuilder(
            animation: _fadeController,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeController.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Image.asset(
                    'assets/main/5.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class ZoomOutAnimator extends StatefulWidget {
  const ZoomOutAnimator({
    super.key,
    required this.child,
    this.beginScale = 1.15,
  });
  final Widget child;
  final double beginScale;

  @override
  State<ZoomOutAnimator> createState() => _ZoomOutAnimatorState();
}

class _ZoomOutAnimatorState extends State<ZoomOutAnimator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = Tween<double>(
      begin: widget.beginScale,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route != null && route.secondaryAnimation != null) {
      return AnimatedBuilder(
        animation: Listenable.merge([_animation, route.secondaryAnimation!]),
        builder: (context, child) {
          final baseScale = _animation.value;
          final secondaryScale = 1.0 + (route.secondaryAnimation!.value * 0.08);
          return Transform.scale(
            scale: baseScale * secondaryScale,
            child: child,
          );
        },
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(scale: _animation.value, child: child);
      },
      child: widget.child,
    );
  }
}

class PulsingRewardSlot extends StatefulWidget {
  final Widget child;
  final bool isWon;
  const PulsingRewardSlot({
    super.key,
    required this.child,
    required this.isWon,
  });
  @override
  State<PulsingRewardSlot> createState() => _PulsingRewardSlotState();
}

class _PulsingRewardSlotState extends State<PulsingRewardSlot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isWon) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(
                0xFF75E8FA,
              ).withValues(alpha: 0.3 + (_controller.value * 0.4)),
              width: 1.0 + (_controller.value * 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF75E8FA,
                ).withValues(alpha: 0.1 + (_controller.value * 0.2)),
                blurRadius: 8 + (_controller.value * 10),
                spreadRadius: 1 + (_controller.value * 2),
              ),
            ],
          ),
          child: widget.child,
        );
      },
      child: widget.child,
    );
  }
}

class HeroContentAnimator extends StatefulWidget {
  const HeroContentAnimator({super.key, required this.onPlay});
  final VoidCallback onPlay;

  @override
  State<HeroContentAnimator> createState() => _HeroContentAnimatorState();
}

class _HeroContentAnimatorState extends State<HeroContentAnimator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  late Animation<double> _introScaleAnimation;
  late Animation<Offset> _introSlideAnimation;
  late Animation<double> _introFadeAnimation;
  late Animation<double> _fontGlitchAnimation;

  late Animation<double> _textOutroFadeAnimation;

  late Animation<double> _dashboardFadeAnimation;
  late Animation<Offset> _dashboardSlideAnimation;

  ModalRoute? _route;

  @override
  void initState() {
    super.initState();
    // 3.8 seconds total for the entire cinematic sequence
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );

    // 0.0 - 0.35: Intro Scale (matches background zoom)
    _introScaleAnimation = Tween<double>(begin: 1.15, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOutCubic),
      ),
    );

    // 0.05 - 0.35: Intro Slide/Fade
    _introSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.05, 0.35, curve: Curves.easeOutCubic),
          ),
        );
    _introFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.05, 0.30, curve: Curves.easeOut),
      ),
    );

    // 0.35 - 0.50: Font Glitch
    _fontGlitchAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.50, curve: Curves.linear),
      ),
    );

    // 0.60 - 0.75: Text Outro Fade (only fade out, no scale)
    _textOutroFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.60, 0.75, curve: Curves.easeOut),
      ),
    );

    // 0.70 - 0.90: Dashboard Slide & Fade In
    _dashboardSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.70, 0.90, curve: Curves.easeOutCubic),
          ),
        );
    _dashboardFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.70, 0.90, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      if (_route != null) {
        _route!.secondaryAnimation?.removeStatusListener(_routeListener);
      }
      _route = route;
      _route?.secondaryAnimation?.addStatusListener(_routeListener);
    }
  }

  void _routeListener(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _route?.secondaryAnimation?.removeStatusListener(_routeListener);
    _controller.dispose();
    super.dispose();
  }

  Widget _buildPlayButton() {
    return GestureDetector(
      onTap: () {
        gameStore.tap(GameSound.start);
        widget.onPlay();
      },
      child: Image.asset(
        'assets/main/meydana_gir.png',
        height: 210, // Slightly smaller
        width: 450,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildTitleText() {
    String? glitchFontFamily;
    final glitchValue = _fontGlitchAnimation.value;
    if (glitchValue > 0.0 && glitchValue < 1.0) {
      int step = (glitchValue * 4).floor();
      switch (step) {
        case 0:
          glitchFontFamily = 'Courier';
          break;
        case 1:
          glitchFontFamily = 'Times New Roman';
          break;
        case 2:
          glitchFontFamily = 'Georgia';
          break;
        case 3:
          glitchFontFamily = 'Trebuchet MS';
          break;
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'MEYDAN',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 64,
            height: 1.0,
            fontWeight: FontWeight.w900,
            letterSpacing: 10.0,
            shadows: [
              Shadow(
                color: Colors.black87,
                blurRadius: 40,
                offset: Offset(0, 10),
              ),
            ],
          ),
        ),
        Text(
          'DÜELLOSU',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFF22E565),
            fontFamily: glitchFontFamily,
            fontSize: 28,
            height: 1.0,
            fontWeight: FontWeight.w800,
            letterSpacing: 16.0,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 20, offset: Offset(0, 5)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(35),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
        child: Container(
          height: 65, // Thinner tab bar
          padding: const EdgeInsets.only(bottom: 2), // Adjusted padding
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.015),
            borderRadius: BorderRadius.circular(35),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Liquid Glass Highlight
              Positioned(
                top: 0,
                left: 16,
                right: 16,
                child: Container(
                  height: 20,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildTabItem(Icons.home_rounded, 'Ana Sayfa', true),
                    _buildTabItem(
                      Icons.emoji_events_rounded,
                      'Liderlik',
                      false,
                    ),
                    _buildTabItem(Icons.storefront_rounded, 'Market', false),
                    _buildTabItem(Icons.person_rounded, 'Profil', false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(IconData icon, String label, bool isSelected) {
    final color = isSelected
        ? const Color(0xFF22E565)
        : Colors.white.withValues(alpha: 0.5);
    return Expanded(
      child: Container(
        color: Colors.transparent, // To catch taps
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: isSelected ? 26 : 24,
              shadows: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyRewards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (index) {
          final isWon = index < 2;

          if (!isWon) {
            // Empty Slot
            return Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: 1.5,
                    sigmaY: 1.5,
                  ), // Less blur
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 110, // Kept original height
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.01),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          // Filled Slot
          final ballImage = index == 0
              ? 'assets/daily/best_ball.png'
              : 'assets/daily/other_ball.png';
          return Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: 1.5,
                  sigmaY: 1.5,
                ), // Less blur
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1.0,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, -8), // Move image slightly up
                        child: Image.asset(
                          ballImage,
                          height: 110, // Increased image size
                          fit: BoxFit.contain,
                        ),
                      ),
                      const Positioned(
                        bottom: 2,
                        child: Text(
                          'AL',
                          style: TextStyle(
                            color: Color(0xFF22E565), // Green text
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 8),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _introScaleAnimation.value,
          child: FractionalTranslation(
            translation: _introSlideAnimation.value,
            child: Opacity(
              opacity: _introFadeAnimation.value,
              child: Stack(
                children: [
                  // 1. MEYDAN DÜELLOSU Text (Fades out in place)
                  Center(
                    child: FractionalTranslation(
                      translation: const Offset(
                        0,
                        -0.15,
                      ), // Moved up slightly more
                      child: FadeTransition(
                        opacity: _textOutroFadeAnimation,
                        child: _buildTitleText(),
                      ),
                    ),
                  ),

                  // 1.5. Emerald Arena Badge (Appears with Dashboard)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom:
                        205 +
                        MediaQuery.of(context).padding.bottom, // Moved 20px up
                    child: FadeTransition(
                      opacity: _dashboardFadeAnimation,
                      child: FractionalTranslation(
                        translation: _dashboardSlideAnimation.value,
                        child: Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Exact Shadow matching the image pixels
                              Transform.translate(
                                offset: const Offset(0, 15),
                                child: ImageFiltered(
                                  imageFilter: ui.ImageFilter.blur(
                                    sigmaX: 20,
                                    sigmaY: 20,
                                  ),
                                  child: ColorFiltered(
                                    colorFilter: ColorFilter.mode(
                                      Colors.black.withValues(alpha: 0.9),
                                      BlendMode.srcIn,
                                    ),
                                    child: Image.asset(
                                      'assets/arenas/emerald.png',
                                      height:
                                          380, // Reduced height to fit new image
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                              Image.asset(
                                'assets/arenas/emerald.png',
                                height: 380, // Same size as the shadow
                                fit: BoxFit.contain,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 2. MEYDANA GİR Button (Moved down closer to rewards)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom:
                        130 +
                        MediaQuery.of(context).padding.bottom, // Moved 10px up
                    child: Center(child: _buildPlayButton()),
                  ),

                  // 2.5. Daily Rewards
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 75 + MediaQuery.of(context).padding.bottom,
                    child: FadeTransition(
                      opacity: _dashboardFadeAnimation,
                      child: FractionalTranslation(
                        translation: _dashboardSlideAnimation.value,
                        child: _buildDailyRewards(),
                      ),
                    ),
                  ),

                  // 3. Liquid Glass Tab Bar (Appears at bottom)
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: -5 + MediaQuery.of(context).padding.bottom,
                    child: FadeTransition(
                      opacity: _dashboardFadeAnimation,
                      child: FractionalTranslation(
                        translation: _dashboardSlideAnimation.value,
                        child: _buildTabBar(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ArenaHero extends StatelessWidget {
  const ArenaHero({super.key, required this.onPlay});
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.transparent,
      child: Stack(
        children: [
          // Centered Text and Premium Glassmorphism Button
          Positioned.fill(child: HeroContentAnimator(onPlay: onPlay)),
        ],
      ),
    );
  }
}
