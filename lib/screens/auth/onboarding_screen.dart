import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:futbol_meydani/constants.dart';
import 'package:futbol_meydani/widgets/common_widgets.dart';
import 'auth_screen.dart';

class _CurveBottomClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(
      size.width / 2,
      size.height + 40,
      size.width,
      size.height - 40,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentPage = 0;

  void _next() {
    if (_currentPage < 1) {
      setState(() => _currentPage = 1);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_currentPage > 0) {
      setState(() => _currentPage = 0);
    }
  }

  void _finish() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const AuthScreen(),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
            child: _currentPage == 0
                ? _buildPage1(key: const ValueKey('page1'))
                : _buildPage2(key: const ValueKey('page2')),
          ),

          // Skip button
          SafeArea(
            child: AnimatedOpacity(
              opacity: _currentPage == 0 ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: _currentPage != 0,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: TextButton(
                      onPressed: _finish,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.black.withValues(alpha: 0.4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'ATLA',
                            style: GoogleFonts.oswald(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage1({Key? key}) {
    return Column(
      key: key,
      children: [
        ClipPath(
          clipper: _CurveBottomClipper(),
          child: Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.55,
            decoration: const BoxDecoration(color: panel),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  'https://images.unsplash.com/photo-1511886929837-354d827aae26?q=90&w=1200&auto=format&fit=crop',
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) => const SizedBox(),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.4),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.2),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(30, 40, 30, 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'KADRONU KUR,\nMEYDANA ÇIK',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.oswald(
                      color: Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Rakibini analiz et, kusursuz ilk 7\'ini kur ve futbol bilgini sahada konuştur!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, fontSize: 17, height: 1.5),
                  ),
                  const SizedBox(height: 30),
                  _buildIndicators(),
                  const SizedBox(height: 30),
                  PrimaryButton(
                    label: 'İLERİ',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: _next,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPage2({Key? key}) {
    return Stack(
      key: key,
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/main/dark_stadium_onboarding.png',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          errorBuilder: (ctx, err, stack) => const SizedBox(),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.7),
                Colors.black.withValues(alpha: 0.2),
                Colors.black.withValues(alpha: 0.8),
                Colors.black,
              ],
              stops: const [0.0, 0.4, 0.8, 1.0],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 140, 30, 40),
            child: Column(
              children: [
                Text(
                  'LİGLERİ\nFETHET',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.oswald(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Zorlu ligleri aş, kupaları topla ve adını efsaneler arasına yazdır!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    height: 1.5,
                  ),
                ),
                const Spacer(),
                _buildIndicators(),
                const SizedBox(height: 30),
                PrimaryButton(
                  label: 'BAŞLA',
                  icon: Icons.sports_soccer_rounded,
                  onPressed: _finish,
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 20, top: 10),
              child: TextButton.icon(
                onPressed: _back,
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                label: const Text(
                  'Geri',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  backgroundColor: Colors.black.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (i) {
        final active = i == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? green : Colors.white24,
            borderRadius: BorderRadius.circular(4),
            boxShadow: active
                ? [
                    const BoxShadow(
                      color: green,
                      blurRadius: 8,
                      spreadRadius: -2,
                    ),
                  ]
                : [],
          ),
        );
      }),
    );
  }
}
