import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'inbox_screen.dart';

import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../globals.dart';
import '../constants.dart';
import '../models/game_data.dart';
import '../widgets/common_widgets.dart';
import '../utils/glass_toast.dart';

import '../widgets/last_minute/last_minute_career_screen.dart';
import 'setup_screen.dart';
import 'squad_challenge_screen.dart';
import '../widgets/online/online_entry_screen.dart';
import 'shop_screen.dart';
import 'friends_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'auth/auth_screen.dart';
import 'auth/onboarding_screen.dart' as auth;
import '../widgets/home/home_widgets.dart';

import '../services/supabase_state.dart';

// â”€â”€â”€ Palette â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const _kNavy0 = Color(0xFF080F1A);
const _kGold0 = Color(0xFFFFE066);
const _kGold1 = Color(0xFFD4A017);
const _kGreen0 = Color(0xFF00E676);
const _kGreen1 = Color(0xFF00B84A);
const _kGreen2 = Color(0xFF006B2B);

// â”€â”€â”€ Shared decoration helper: border-only outer box â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Flutter throws "borderRadius can only be given on borders with uniform colors"
// when gradient + border + borderRadius appear together in one BoxDecoration.
// Fix: border lives on the outer Container, gradient lives in the inner Container.
BoxDecoration _borderBox({
  required double radius,
  required Color borderColor,
  double borderWidth = 1.2,
  List<BoxShadow> shadows = const [],
}) => BoxDecoration(
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: borderColor, width: borderWidth),
  boxShadow: shadows,
);

BoxDecoration _gradientBox({
  required List<Color> colors,
  double radius = 0,
  Alignment begin = Alignment.topLeft,
  Alignment end = Alignment.bottomRight,
}) => BoxDecoration(
  borderRadius: radius > 0 ? BorderRadius.circular(radius) : null,
  gradient: LinearGradient(colors: colors, begin: begin, end: end),
);

// â”€â”€â”€ Enum & Model â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
enum AppGameMode { lastMinute, localVersus, squadStrategy, onlineVersus }

class ModeInfo {
  final String title;
  final String tag;
  final IconData icon;
  final Color color;
  const ModeInfo(this.title, this.tag, this.icon, this.color);
}

const Map<AppGameMode, ModeInfo> kModeDetails = {
  AppGameMode.lastMinute: ModeInfo(
    'Son Dakika',
    'CEVRIMDISi',
    Icons.electric_bolt_rounded,
    Color(0xFF94A3B8),
  ),
  AppGameMode.localVersus: ModeInfo(
    'Karsili Meydan',
    'AYNI TELEFON',
    Icons.gamepad_rounded,
    Color(0xFFFF9800),
  ),
  AppGameMode.squadStrategy: ModeInfo(
    'Meydan Kadrosu',
    'AYNI TELEFON',
    Icons.shield_rounded,
    Color(0xFFFF9800),
  ),
  AppGameMode.onlineVersus: ModeInfo(
    'Online Meydan',
    'CEVRIMICI',
    Icons.language_rounded,
    Color(0xFF22D3EE),
  ),
};

// keep Turkish display strings separately to avoid encoding issues in const maps
String modeDisplayTitle(AppGameMode m) {
  switch (m) {
    case AppGameMode.lastMinute:
      return 'Son Dakika';
    case AppGameMode.localVersus:
      return 'Karşılıklı Meydan';
    case AppGameMode.squadStrategy:
      return 'Meydan Kadrosu';
    case AppGameMode.onlineVersus:
      return 'Online Meydan';
  }
}

String modeDisplayTag(AppGameMode m) {
  switch (m) {
    case AppGameMode.lastMinute:
      return 'ÇEVRİMDIŞI';
    case AppGameMode.localVersus:
      return 'AYNI TELEFON';
    case AppGameMode.squadStrategy:
      return 'AYNI TELEFON';
    case AppGameMode.onlineVersus:
      return 'ÇEVRİMİÇİ';
  }
}

// â”€â”€â”€ HomeScreen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.data});
  final GameData data;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 1;
  late final PageController _pageController;
  AppGameMode _selectedMode = AppGameMode.lastMinute;

  late final AnimationController _dotCtrl;
  late final Animation<double> _dotAnim;
  late final AnimationController _entryCtrl;
  late final Animation<Offset> _entrySlide;
  late final Animation<double> _entryFade;

  int _lastTrophies = 0;
  int _lastCoins = 0;

  bool get _hasOnlineSession =>
      SupabaseState.client?.auth.currentSession != null;

  void _openAuthScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);

    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _dotAnim = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _dotCtrl, curve: Curves.easeInOut));

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutQuart));
    _entryFade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _entryCtrl.forward();

    _lastTrophies = gameStore.trophies;
    _lastCoins = gameStore.coins;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _dotCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  void _launch() {
    switch (_selectedMode) {
      case AppGameMode.lastMinute:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LastMinuteCareerScreen()),
        );
        break;
      case AppGameMode.localVersus:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SetupScreen(data: widget.data)),
        );
        break;
      case AppGameMode.squadStrategy:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SquadSetupScreen(data: widget.data),
          ),
        );
        break;
      case AppGameMode.onlineVersus:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OnlineEntryScreen(data: widget.data),
          ),
        );
        break;
    }
  }

  void showHowToPlay(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: panel2,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Meydanını seç.',
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            // Note: double-quoted string to avoid apostrophe issue
            const Text(
              "Futbol Meydanı'nda her mod farklı bir yeteneğini sınar.",
              style: TextStyle(color: muted, height: 1.4),
            ),
            const SizedBox(height: 20),
            const HomeHowToRow(
              number: '1',
              title: 'Son Dakika',
              text:
                  'Refleksini kullan, hücum yolunu çiz ve kariyer etaplarında kaleye ulaş.',
            ),
            const HomeHowToRow(
              number: '2',
              title: 'Meydan Düellosu',
              text:
                  'Aynı telefonda veya çevrimiçi rakibine karşı hedefe en yakın kadroyu kur.',
            ),
            const HomeHowToRow(
              number: '3',
              title: 'Kadro Stratejisi',
              text:
                  'Kura, takım banı ve doğru mevki seçimleriyle rakibinden daha iyi plan yap.',
            ),
            const SizedBox(height: 10),
            PrimaryButton(
              label: 'Meydanlara Dön',
              icon: Icons.stadium_rounded,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    ),
  );

  void _showModesSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => _ModesSheet(
        selectedMode: _selectedMode,
        onSelect: (m) {
          setState(() => _selectedMode = m);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _handleProfileMenu(int index) async {
    if (index == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
    } else if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const InboxScreen()),
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
    } else if (index == 3) {
      final confirm = await showGeneralDialog<bool>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Logout',
        barrierColor: Colors.black.withValues(alpha: 0.7),
        pageBuilder: (context, anim1, anim2) => const SizedBox(),
        transitionDuration: const Duration(milliseconds: 300),
        transitionBuilder: (context, anim1, anim2, child) {
          return ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            ),
            child: FadeTransition(
              opacity: anim1,
              child: AlertDialog(
                backgroundColor: Colors.transparent,
                contentPadding: EdgeInsets.zero,
                elevation: 0,
                content: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.logout_rounded,
                              color: Colors.redAccent,
                              size: 36,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Çıkış Yap',
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Gerçekten hesabınızdan çıkış yapmak istiyor musunuz?',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: Colors.white70,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.1,
                                    ),
                                  ),
                                  child: Text(
                                    'Vazgeç',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    backgroundColor: Colors.redAccent
                                        .withValues(alpha: 0.9),
                                  ),
                                  child: Text(
                                    'Çıkış',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );

      if (confirm != true) return;

      final client = SupabaseState.client;
      if (client != null) {
        await client.auth.signOut();
      }
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const auth.OnboardingScreen()),
          (r) => false,
        );
      }
    } else if (index == 4) {
      _openAuthScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_lastTrophies != gameStore.trophies) _lastTrophies = gameStore.trophies;
    if (_lastCoins != gameStore.coins) _lastCoins = gameStore.coins;
    final topPad = MediaQuery.of(context).padding.top;

    return AnimatedBuilder(
      animation: gameStore,
      builder: (_, _) => Scaffold(
        backgroundColor: _kNavy0,
        resizeToAvoidBottomInset: false,
        extendBody: true,
        bottomNavigationBar: _BottomBar(
          currentIndex: _currentIndex,
          dotAnim: _dotAnim,
          onTap: (i) {
            GlassToast.dismissAll();
            setState(() => _currentIndex = i);
            _pageController.animateToPage(
              i,
              duration: const Duration(milliseconds: 750),
              curve: Curves.easeOutQuart,
            );
          },
        ),
        body: PageView(
          physics: const ClampingScrollPhysics(),
          controller: _pageController,
          onPageChanged: (i) {
            GlassToast.dismissAll();
            setState(() => _currentIndex = i);
          },
          children: [
            const ShopScreen(),
            _buildHomeTab(topPad),
            const FriendsScreen(),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab(double topPad) {
    return Stack(
      children: [
        // Video bg
        Positioned.fill(
          child: ClipRect(
            child: ZoomOutAnimator(
              beginScale: 1.12,
              child: const VideoBackground(videoPath: 'assets/main/hero.mp4'),
            ),
          ),
        ),
        // Radial vignette â€” pure black, not navy
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.05,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.50),
                  Colors.black.withValues(alpha: 0.85),
                ],
                stops: const [0.30, 0.68, 1.0],
              ),
            ),
          ),
        ),
        // Top + bottom overlays â€” pure black fade, blends into bar
        Positioned.fill(
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xCC000000), // top: solid black
                  Colors.transparent,
                  Colors.transparent,
                  Color(
                    0xF5000000,
                  ), // bottom: near-opaque black â†’ merges with bar
                ],
                stops: [0.0, 0.16, 0.52, 1.0],
              ),
            ),
          ),
        ),

        // Top HUD
        Positioned(
          top: topPad + 12,
          left: 16,
          right: 16,
          child: FadeTransition(
            opacity: _entryFade,
            child: SlideTransition(
              position: _entrySlide,
              child: _TopHud(
                trophies: gameStore.trophies,
                lastTrophies: _lastTrophies,
                coins: gameStore.coins,
                lastCoins: _lastCoins,
                level: gameStore.level,
                playerName: gameStore.playerName,
                isOnline: _hasOnlineSession,
                onProfileTap: _handleProfileMenu,
                onAddCoinsTap: () {
                  gameStore.tap();
                  setState(() => _currentIndex = 0);
                },
              ),
            ),
          ),
        ),

        // Daily reward badge
        if (gameStore.dailyRewardAvailable)
          Positioned(
            top: topPad + 88,
            left: 16,
            child: FadeTransition(
              opacity: _entryFade,
              child: const _DailyRewardBadge(),
            ),
          ),

        // CTA row
        Positioned(
          bottom: 100,
          left: 24,
          right: 24,
          child: FadeTransition(
            opacity: _entryFade,
            child: SlideTransition(
              position: _entrySlide,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _CtaButton(mode: _selectedMode, onTap: _launch),
                  ),
                  const SizedBox(width: 10),
                  _ModPickerButton(onTap: _showModesSheet),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ————————————————————————————————————————————————————————————————————————————————————————————————————
// TOP HUD
// ————————————————————————————————————————————————————————————————————————————————————————————————————
class _TopHud extends StatelessWidget {
  final int trophies, lastTrophies, coins, lastCoins, level;
  final String playerName;
  final bool isOnline;
  final ValueChanged<int> onProfileTap;
  final VoidCallback? onAddCoinsTap;

  const _TopHud({
    required this.trophies,
    required this.lastTrophies,
    required this.coins,
    required this.lastCoins,
    required this.level,
    required this.playerName,
    required this.isOnline,
    required this.onProfileTap,
    this.onAddCoinsTap,
  });

  Widget _buildMenuRow(
    BuildContext context,
    int value,
    IconData icon,
    String text,
    Color textColor,
    Color iconColor,
    void Function({bool instant}) close,
  ) {
    return InkWell(
      onTap: () {
        close(instant: true);
        onProfileTap(value);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _GlassDropdownButton(
          menuBuilder: (context, close) => ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: 250,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMenuRow(
                      context,
                      0,
                      Icons.person_rounded,
                      'Profil Bilgileri',
                      Colors.white,
                      Colors.white70,
                      close,
                    ),
                    _buildMenuRow(
                      context,
                      1,
                      Icons.inbox_rounded,
                      'Gelen Kutusu',
                      Colors.white,
                      Colors.white70,
                      close,
                    ),
                    _buildMenuRow(
                      context,
                      2,
                      Icons.settings_rounded,
                      'Ayarlar',
                      Colors.white,
                      Colors.white70,
                      close,
                    ),
                    const Divider(height: 1, color: Colors.white12),
                    if (isOnline)
                      _buildMenuRow(
                        context,
                        3,
                        Icons.logout_rounded,
                        'Hesaptan Çıkış Yap',
                        Colors.redAccent,
                        Colors.redAccent,
                        close,
                      )
                    else
                      _buildMenuRow(
                        context,
                        4,
                        Icons.login_rounded,
                        'Giriş Yap / Hesap Oluştur',
                        const Color(0xFF00E676),
                        const Color(0xFF00E676),
                        close,
                      ),
                  ],
                ),
              ),
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Avatar: outer border ring (gold) — no gradient here to avoid the error
              Container(
                width: 54,
                height: 54,
                decoration: _borderBox(
                  radius: 27,
                  borderColor: _kGold1,
                  borderWidth: 2,
                  shadows: [
                    BoxShadow(
                      color: _kGold1.withValues(alpha: 0.22),
                      blurRadius: 8,
                    ),
                  ],
                ),
                // Inner avatar circle: gradient, no border
                child: ClipOval(
                  child: Container(
                    decoration: _gradientBox(
                      colors: [
                        const Color(0xFF1E2D42),
                        const Color(0xFF0D1825),
                      ],
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Color(0xBBFFFFFF),
                      size: 28,
                    ),
                  ),
                ),
              ),
              // Level badge — bottom-right, overlapping avatar
              Positioned(
                bottom: -1,
                right: -5,
                child: Container(
                  // border wrapper
                  decoration: _borderBox(
                    radius: 6,
                    borderColor: _kNavy0,
                    borderWidth: 1.5,
                    shadows: [
                      BoxShadow(
                        color: _kGreen0.withValues(alpha: 0.2),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4.5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: _gradientBox(
                        colors: [_kGreen0, _kGreen2],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      child: Text(
                        'Lv$level',
                        style: GoogleFonts.oswald(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          shadows: const [
                            Shadow(color: Colors.black38, blurRadius: 2),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                playerName.isNotEmpty ? playerName.toUpperCase() : 'OYUNCU',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.oswald(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  shadows: const [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isOnline ? _kGreen0 : const Color(0xFF94A3B8),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isOnline ? 'ÇEVRİMİÇİ' : 'ÇEVRİMDIŞI • GİRİŞ YAP',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: isOnline ? _kGreen0 : const Color(0xFFCBD5E1),
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.45,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        Row(
          children: [
            _ResourceBadge(
              icon: Icons.emoji_events_rounded,
              value: trophies,
              oldValue: lastTrophies,
              accentColor: _kGold1,
              bgColors: [const Color(0xFF2A1E00), const Color(0xFF1A1200)],
              borderColor: _kGold1.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 7),
            _ResourceBadge(
              icon: Icons.monetization_on_rounded,
              value: coins,
              oldValue: lastCoins,
              accentColor: _kGreen0,
              bgColors: [const Color(0xFF003818), const Color(0xFF001E0B)],
              borderColor: _kGreen0.withValues(alpha: 0.38),
              showAdd: true,
              onAddTap: onAddCoinsTap,
            ),
          ],
        ),
      ],
    );
  }
}

// â”€â”€â”€ Resource badge â€” border and gradient kept in separate BoxDecorations â”€â”€â”€â”€
class _ResourceBadge extends StatelessWidget {
  final IconData icon;
  final int value, oldValue;
  final Color accentColor;
  final List<Color> bgColors;
  final Color borderColor;
  final bool showAdd;
  final VoidCallback? onAddTap;

  const _ResourceBadge({
    required this.icon,
    required this.value,
    required this.oldValue,
    required this.accentColor,
    required this.bgColors,
    required this.borderColor,
    this.showAdd = false,
    this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    const r = 10.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onAddTap,
      child: Container(
        // OUTER: border + shadows ONLY â€” no gradient
        decoration: _borderBox(
          radius: r,
          borderColor: borderColor,
          borderWidth: 1.2,
          shadows: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.15),
              blurRadius: 8,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(r - 1.2),
          child: Stack(
            children: [
              // INNER: gradient ONLY â€” no border
              Container(
                padding: EdgeInsets.fromLTRB(9, 5, showAdd ? 6 : 12, 5),
                decoration: _gradientBox(
                  colors: bgColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ShaderMask(
                      shaderCallback: (b) => LinearGradient(
                        colors: [
                          accentColor,
                          accentColor.withValues(alpha: 0.65),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ).createShader(b),
                      child: Icon(icon, color: Colors.white, size: 17),
                    ),
                    const SizedBox(width: 5),
                    TweenAnimationBuilder<int>(
                      tween: IntTween(begin: oldValue, end: value),
                      duration: const Duration(milliseconds: 700),
                      builder: (_, v, _) => Text(
                        '$v',
                        style: GoogleFonts.oswald(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          shadows: [
                            Shadow(
                              color: accentColor.withValues(alpha: 0.4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (showAdd) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _kGreen0.withValues(alpha: 0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Container(
                            decoration: _gradientBox(
                              colors: [_kGreen0, _kGreen1],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: Colors.black87,
                              size: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Glass highlight â€” top shimmer
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// DAILY REWARD BADGE
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _DailyRewardBadge extends StatelessWidget {
  const _DailyRewardBadge();

  void _claimReward(BuildContext context) async {
    final isClaimed = await gameStore.claimDailyRewardCoins();
    if (isClaimed) {
      gameStore.success();
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF150F00),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: _kGold0, width: 2),
            ),
            title: Row(
              children: [
                const Icon(Icons.stars_rounded, color: _kGold0, size: 28),
                const SizedBox(width: 8),
                Text(
                  'GÜNLÜK ÖDÜL ALINDI!',
                  style: GoogleFonts.oswald(
                    color: _kGold0,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.monetization_on_rounded,
                  color: _kGreen0,
                  size: 54,
                ),
                const SizedBox(height: 12),
                const Text(
                  '+500 MP KAZANDIN!',
                  style: TextStyle(
                    color: _kGreen0,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tebrikler! Günlük giriş ödülü olarak 500 Coin hesabına eklendi. Yarın tekrar gelmeyi unutma!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  gameStore.tap(GameSound.tap);
                  Navigator.pop(ctx);
                },
                child: const Text(
                  'HARİKA',
                  style: TextStyle(
                    color: _kGold0,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } else {
      gameStore.tap(GameSound.warning);
      final lastTime = gameStore.lastDailyRewardTime;
      final diff = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(lastTime),
      );
      final totalSecRemaining = (86400 - diff.inSeconds);
      final hoursRemaining = totalSecRemaining ~/ 3600;
      final minsRemaining = (totalSecRemaining % 3600) ~/ 60;

      if (context.mounted) {
        GlassToast.show(
          context,
          'Ödül henüz hazır değil. $hoursRemaining saat $minsRemaining dakika sonra tekrar gel!',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const r = 12.0;
    return ListenableBuilder(
      listenable: gameStore,
      builder: (context, _) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final lastTime = gameStore.lastDailyRewardTime;
        final isReady = lastTime == 0 || now - lastTime >= 86400000;

        String subtitleText;
        if (isReady) {
          subtitleText = 'HAZIR! (+500 MP)';
        } else {
          final diff = DateTime.now().difference(
            DateTime.fromMillisecondsSinceEpoch(lastTime),
          );
          final remainingSec = (86400 - diff.inSeconds).clamp(0, 86400);
          final h = remainingSec ~/ 3600;
          final m = (remainingSec % 3600) ~/ 60;
          subtitleText = '$h saat $m dk kaldı';
        }

        return GestureDetector(
          onTap: () => _claimReward(context),
          child: Container(
            decoration: _borderBox(
              radius: r,
              borderColor: isReady ? _kGold0 : _kGold1.withValues(alpha: 0.45),
              borderWidth: isReady ? 1.8 : 1.2,
              shadows: [
                BoxShadow(
                  color: isReady
                      ? _kGold0.withValues(alpha: 0.35)
                      : _kGold1.withValues(alpha: 0.18),
                  blurRadius: isReady ? 16 : 12,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(r - 1.2),
              child: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: _gradientBox(
                      colors: isReady
                          ? [const Color(0xFF382A00), const Color(0xFF1E1500)]
                          : [const Color(0xFF221A00), const Color(0xFF150F00)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ShaderMask(
                          shaderCallback: (b) => LinearGradient(
                            colors: isReady
                                ? [_kGold0, Colors.white]
                                : [_kGold0, _kGold1],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ).createShader(b),
                          child: Icon(
                            isReady
                                ? Icons.card_giftcard_rounded
                                : Icons.lock_clock_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'GÜNLÜK ÖDÜL',
                              style: GoogleFonts.oswald(
                                color: _kGold0,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.6,
                                shadows: const [
                                  Shadow(color: Colors.black54, blurRadius: 3),
                                ],
                              ),
                            ),
                            Text(
                              subtitleText,
                              style: TextStyle(
                                color: isReady ? _kGreen0 : Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                shadows: [
                                  Shadow(
                                    color: (isReady ? _kGreen0 : Colors.white70)
                                        .withValues(alpha: 0.5),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.15),
                            Colors.transparent,
                          ],
                        ),
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

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// CTA BUTTON
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _CtaButton extends StatefulWidget {
  final AppGameMode mode;
  final VoidCallback onTap;
  const _CtaButton({required this.mode, required this.onTap});

  @override
  State<_CtaButton> createState() => _CtaButtonState();
}

class _CtaButtonState extends State<_CtaButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isLive = widget.mode == AppGameMode.lastMinute;
    const r = 24.0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF00C853), Color(0xFF008833)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(r - 1.5),
                    ),
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.15),
                      ),
                      child: Icon(
                        isLive
                            ? Icons.sports_soccer_rounded
                            : kModeDetails[widget.mode]!.icon,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MEYDANA GİR',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          modeDisplayTitle(widget.mode).toUpperCase(),
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11,
                            letterSpacing: 0.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// MODE PICKER BUTTON â€” sibling of CTA
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _ModPickerButton extends StatefulWidget {
  final VoidCallback onTap;
  const _ModPickerButton({required this.onTap});

  @override
  State<_ModPickerButton> createState() => _ModPickerButtonState();
}

class _ModPickerButtonState extends State<_ModPickerButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    const r = 24.0;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r),
            color: const Color(0xFF050505),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(r - 1.5),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: Icon(
                  Icons.dashboard_customize_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// MODES BOTTOM SHEET
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _ModesSheet extends StatelessWidget {
  final AppGameMode selectedMode;
  final ValueChanged<AppGameMode> onSelect;
  const _ModesSheet({required this.selectedMode, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.5, 1.0],
              colors: [
                Colors.white.withValues(alpha: 0.08),
                Colors.black.withValues(alpha: 0.3),
                Colors.black.withValues(alpha: 0.95),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Grabber
                  Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Oyun Modu Seçin',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...AppGameMode.values.map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ModeCard(
                        mode: m,
                        isSelected: m == selectedMode,
                        onTap: () => onSelect(m),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatefulWidget {
  final AppGameMode mode;
  final bool isSelected;
  final VoidCallback onTap;
  const _ModeCard({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final info = kModeDetails[widget.mode]!;
    final sel = widget.isSelected;
    final color = sel ? const Color(0xFF71F39A) : Colors.white;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: sel
                ? color.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: sel
                  ? color.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.08),
              width: 1.5,
            ),
            boxShadow: sel
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.1),
                      blurRadius: 12,
                      spreadRadius: 0,
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(info.icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      modeDisplayTitle(widget.mode),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      modeDisplayTag(widget.mode),
                      style: GoogleFonts.inter(
                        color: widget.mode == AppGameMode.onlineVersus
                            ? const Color(0xFF5EC8FF)
                            : widget.mode == AppGameMode.lastMinute
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFFFFD166),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                sel ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                color: sel ? color : Colors.white38,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// BOTTOM BAR  â€” slim dark strip, badge-style active
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _BottomBar extends StatefulWidget {
  final int currentIndex;
  final Animation<double> dotAnim;
  final ValueChanged<int> onTap;
  const _BottomBar({
    required this.currentIndex,
    required this.dotAnim,
    required this.onTap,
  });

  @override
  State<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<_BottomBar> {
  double? _dragX;
  double? _dragWidth;
  bool _isDragging = false;
  int? _hoverIndex;

  void _handlePointerDown(Offset localPosition, double width) {
    final itemWidth = width / 3;
    final hIndex = (localPosition.dx / itemWidth).floor().clamp(0, 2);

    if (hIndex == widget.currentIndex) {
      _updateDragState(localPosition.dx, width, hIndex, isDown: true);
    } else {
      widget.onTap(hIndex);
      setState(() {
        _hoverIndex = hIndex;
      });
    }
    HapticFeedback.lightImpact();
  }

  void _handlePointerUpdate(Offset localPosition, double width) {
    final itemWidth = width / 3;
    final hIndex = (localPosition.dx / itemWidth).floor().clamp(0, 2);
    if (_hoverIndex != hIndex) HapticFeedback.selectionClick();
    _updateDragState(localPosition.dx, width, hIndex, isDown: true);
  }

  void _updateDragState(
    double dx,
    double width,
    int hIndex, {
    bool isDown = false,
  }) {
    final itemWidth = width / 3;
    double rawX = dx - (itemWidth / 2);
    double maxX = width - itemWidth;

    double newX;
    double newWidth;

    if (rawX < 0) {
      // Hit left wall -> squish
      newX = 0;
      newWidth = itemWidth - (rawX.abs() * 0.35);
      if (newWidth < itemWidth * 0.6) newWidth = itemWidth * 0.6;
    } else if (rawX > maxX) {
      // Hit right wall -> squish
      newWidth = itemWidth - ((rawX - maxX) * 0.35);
      if (newWidth < itemWidth * 0.6) newWidth = itemWidth * 0.6;
      newX = (maxX + itemWidth) - newWidth;
    } else {
      newX = rawX;
      newWidth = itemWidth;
    }

    setState(() {
      if (isDown) _isDragging = true;
      _dragX = newX;
      _dragWidth = newWidth;
      _hoverIndex = hIndex;
    });
  }

  void _handlePointerUp(double width) {
    if (_isDragging && _dragX != null) {
      final itemWidth = width / 3;
      final pillCenter = _dragX! + (itemWidth / 2);
      final index = (pillCenter / itemWidth).floor().clamp(0, 2);

      if (index != widget.currentIndex) {
        widget.onTap(index);
        HapticFeedback.lightImpact();
      }
    }

    setState(() {
      _isDragging = false;
      _dragX = null;
      _dragWidth = null;
      _hoverIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final highlightIndex = _hoverIndex ?? widget.currentIndex;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: bottomPad > 0 ? 12 : 20,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / 3;
                return GestureDetector(
                  onPanDown: (details) => _handlePointerDown(
                    details.localPosition,
                    constraints.maxWidth,
                  ),
                  onPanUpdate: (details) => _handlePointerUpdate(
                    details.localPosition,
                    constraints.maxWidth,
                  ),
                  onPanEnd: (_) => _handlePointerUp(constraints.maxWidth),
                  onPanCancel: () => _handlePointerUp(constraints.maxWidth),
                  behavior: HitTestBehavior.opaque,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Animated Indicator Pill
                      AnimatedPositioned(
                        duration: _isDragging
                            ? const Duration(milliseconds: 70)
                            : const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic,
                        left: _isDragging
                            ? _dragX!
                            : widget.currentIndex * itemWidth,
                        top: 0,
                        bottom: 0,
                        width: _isDragging ? _dragWidth! : itemWidth,
                        child: AnimatedScale(
                          scale: _isDragging ? 1.08 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 0,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(32),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: 0.12),
                                  Colors.white.withValues(alpha: 0.02),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                                width: 1,
                              ),
                              boxShadow: _isDragging
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.2,
                                        ),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : [],
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          _buildTabItem(
                            0,
                            highlightIndex,
                            Icons.shopping_bag_rounded,
                            'Mağaza',
                            false,
                          ),
                          _buildTabItem(
                            1,
                            highlightIndex,
                            Icons.sports_soccer_rounded,
                            'Ana Sayfa',
                            false,
                          ),
                          _buildTabItem(
                            2,
                            highlightIndex,
                            Icons.group_rounded,
                            'Arkadaşlar',
                            false,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(
    int index,
    int activeIndex,
    IconData icon,
    String label,
    bool hasNotif,
  ) {
    final isSelected = index == activeIndex;
    final color = isSelected
        ? Colors.white
        : Colors.white.withValues(alpha: 0.5);
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(icon, color: color, size: isSelected ? 24 : 24),
                ),
                if (hasNotif)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: AnimatedBuilder(
                      animation: widget.dotAnim,
                      builder: (_, _) => Opacity(
                        opacity: widget.dotAnim.value,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF4757),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.inter(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// HOW TO PLAY ROW
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class HomeHowToRow extends StatelessWidget {
  const HomeHowToRow({
    super.key,
    required this.number,
    required this.title,
    required this.text,
  });
  final String number, title, text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _kGreen0.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: _kGreen0,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                text,
                style: const TextStyle(
                  color: Color(0xFFAFC4B6),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _GlassDropdownButton extends StatefulWidget {
  final Widget child;
  final Widget Function(
    BuildContext context,
    void Function({bool instant}) close,
  )
  menuBuilder;
  const _GlassDropdownButton({required this.child, required this.menuBuilder});

  @override
  State<_GlassDropdownButton> createState() => _GlassDropdownButtonState();
}

class _GlassDropdownButtonState extends State<_GlassDropdownButton>
    with TickerProviderStateMixin {
  final _key = GlobalKey();
  OverlayEntry? _entry;
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late AnimationController _bounceCtrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      ),
    );
    _fadeAnim = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _bounceCtrl.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    if (_entry != null) {
      _entry!.remove();
      _entry = null;
    }
  }

  void _close({bool instant = false}) {
    if (_entry != null) {
      if (instant) {
        _removeOverlay();
        _ctrl.reset();
        _bounceCtrl.reset();
      } else {
        _bounceCtrl.forward().then((_) => _bounceCtrl.reverse());
        _ctrl.reverse().then((_) => _removeOverlay());
      }
    }
  }

  void _toggleMenu() {
    if (_entry != null) {
      _close();
    } else {
      final renderBox = _key.currentContext!.findRenderObject() as RenderBox;
      final offset = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;

      _entry = OverlayEntry(
        builder: (context) {
          return Stack(
            children: [
              GestureDetector(
                onTap: () => _close(),
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.transparent),
              ),
              Positioned(
                top: offset.dy + size.height + 12,
                left: offset.dx,
                child: Material(
                  color: Colors.transparent,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    alignment: Alignment.topLeft,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: widget.menuBuilder(context, _close),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
      Overlay.of(context).insert(_entry!);
      _ctrl.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      key: _key,
      onPointerDown: (_) => _bounceCtrl.forward(),
      onPointerUp: (_) {
        _bounceCtrl.reverse();
        _toggleMenu();
      },
      onPointerCancel: (_) => _bounceCtrl.reverse(),
      child: ScaleTransition(
        scale: Tween<double>(
          begin: 1.0,
          end: 0.9,
        ).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeOut)),
        child: widget.child,
      ),
    );
  }
}
