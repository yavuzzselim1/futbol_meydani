import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:futbol_meydani/constants.dart';
import '../../widgets/common_widgets.dart';
import '../../utils/glass_toast.dart';
import 'package:futbol_meydani/globals.dart';
import 'email_auth_screen.dart';

import '../../services/supabase_state.dart';
import '../home_screen.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  void _showEmailSheet(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EmailAuthScreen()),
    );
  }

  Future<void> continueOffline(BuildContext context) async {
    final client = SupabaseState.client;

    // Explicitly sign out of online session when choosing offline mode
    if (client != null) {
      try {
        await client.auth.signOut();
      } catch (_) {}
    }

    // Reset cached online profile and set clean offline guest profile
    await gameStore.resetAllData();
    gameStore.playerName = 'Çevrimdışı Oyuncu';
    await gameStore.prefs.setString('playerName', 'Çevrimdışı Oyuncu');

    final data = gameStore.data;

    if (data == null) {
      GlassToast.show(context, 'Oyun verileri henüz yüklenemedi.', isError: true);
      return;
    }

    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(data: data)),
        (route) => false,
      );
    }
  }

  Future<void> _signInWithApple(BuildContext context) async {
    final client = SupabaseState.client;

    if (client == null) {
      GlassToast.show(context, 'Çevrimiçi giriş şu anda kullanılamıyor.', isError: true);
      return;
    }
    try {
      // Stub for Apple Sign-In
      await client.auth.signInWithOAuth(OAuthProvider.apple);
    } catch (e) {
      if (context.mounted) {
        GlassToast.show(context, 'Hata: $e', isError: true);
      }
    }
  }

  Future<void> _signInWithGoogle(BuildContext context) async {
    final client = SupabaseState.client;

    if (client == null) {
      GlassToast.show(context, 'Çevrimiçi giriş şu anda kullanılamıyor.', isError: true);
      return;
    }
    try {
      // Stub for Google Sign-In
      await client.auth.signInWithOAuth(OAuthProvider.google);
    } catch (e) {
      if (context.mounted) {
        GlassToast.show(context, 'Hata: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080F1A),
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/branding/auth_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          // Dark Gradient Overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.2),
                    Colors.black.withValues(alpha: 0.7),
                    bg,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Spacer(flex: 2),
                        // Logo & Welcome
                        Center(
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(26),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black45,
                                  blurRadius: 20,
                                  offset: Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(26),
                              child: Image.asset(
                                'assets/branding/app_icon.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'FUTBOL MEYDANI',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.oswald(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 10),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Kariyerine başlamak için giriş yap',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: muted, fontSize: 15),
                        ),
                        const Spacer(flex: 2),

                        // Auth Buttons
                        _AuthButton(
                          label: 'Apple ile Devam Et',
                          iconPath: null, // Using icon directly for now
                          icon: Icons.apple_rounded,
                          bgColor: Colors.black,
                          fgColor: Colors.white,
                          borderColor: Colors.white24,
                          disabled: true,
                          onTap: () => _signInWithApple(context),
                        ),
                        const SizedBox(height: 16),

                        _AuthButton(
                          label: 'Google ile Devam Et',
                          iconPath: null,
                          icon: Icons
                              .g_mobiledata_rounded, // fallback if no asset
                          bgColor: Colors.white,
                          fgColor: Colors.black87,
                          borderColor: Colors.transparent,
                          disabled: false,
                          onTap: () => _signInWithGoogle(context),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 1,
                                color: Colors.white10,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'veya',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: Colors.white10,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        _AuthButton(
                          label: 'E-posta ile Devam Et',
                          icon: Icons.mail_outline_rounded,
                          bgColor: Colors.transparent,
                          fgColor: Colors.white,
                          borderColor: Colors.white38,
                          isCustom: false,
                          onTap: () => _showEmailSheet(context),
                        ),
                        const SizedBox(height: 12),

                        _AuthButton(
                          label: 'Çevrimdışı Devam Et',
                          icon: Icons.cloud_off_rounded,
                          bgColor: const Color(0xFF153C2D),
                          fgColor: Colors.white,
                          borderColor: const Color(0xFF69F0AE),
                          onTap: () => continueOffline(context),
                        ),

                        const Spacer(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthButton extends StatefulWidget {
  final String label;
  final String? iconPath;
  final IconData? icon;
  final Color bgColor;
  final Color fgColor;
  final Color borderColor;
  final bool isCustom;
  final bool disabled;
  final VoidCallback onTap;

  const _AuthButton({
    required this.label,
    this.iconPath,
    this.icon,
    required this.bgColor,
    required this.fgColor,
    required this.borderColor,
    this.isCustom = false,
    this.disabled = false,
    required this.onTap,
  });

  @override
  State<_AuthButton> createState() => _AuthButtonState();
}

class _AuthButtonState extends State<_AuthButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.disabled
          ? null
          : (_) => setState(() => _pressed = true),
      onTapUp: widget.disabled
          ? null
          : (_) {
              setState(() => _pressed = false);
              gameStore.tap();
              widget.onTap();
            },
      onTapCancel: widget.disabled
          ? null
          : () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Opacity(
          opacity: widget.disabled ? 0.45 : 1.0,
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: widget.bgColor,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: widget.borderColor,
                    width: widget.isCustom ? 1.5 : 1.0,
                  ),
                  boxShadow: widget.isCustom
                      ? [
                          BoxShadow(
                            color: widget.borderColor.withValues(alpha: 0.2),
                            blurRadius: 12,
                          ),
                          const BoxShadow(
                            color: Colors.black54,
                            blurRadius: 5,
                            offset: Offset(0, 3),
                          ),
                        ]
                      : [
                          const BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null)
                      Icon(
                        widget.icon,
                        color: widget.fgColor,
                        size: widget.icon == Icons.g_mobiledata_rounded
                            ? 32
                            : 24,
                      ),
                    if (widget.icon != null) const SizedBox(width: 10),
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: widget.fgColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.disabled)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade800,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(30),
                        bottomLeft: Radius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Yakında Aktif',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
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
