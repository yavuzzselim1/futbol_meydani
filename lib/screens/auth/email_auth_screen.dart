import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:futbol_meydani/utils/glass_toast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lottie/lottie.dart';

import 'package:futbol_meydani/constants.dart';
import 'package:futbol_meydani/globals.dart';
import 'package:futbol_meydani/models/progress_merge.dart';
import 'package:futbol_meydani/widgets/offline_progress_merge_dialog.dart';
import 'package:futbol_meydani/widgets/invite_overlay.dart';
import '../home_screen.dart';

import '../../services/supabase_state.dart';

class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  bool _isLogin = true;
  bool _loading = false;
  String _error = '';

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _nickCtrl = TextEditingController();

  String _friendlyAuthError(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid api key')) {
      return 'Supabase anahtarı geçersiz veya proje adresiyle eşleşmiyor. '
          'Publishable key ve SUPABASE_URL değerlerini kontrol et.';
    }
    if (message.contains('invalid login credentials')) {
      return 'E-posta adresi hatalı veya kayıtlı değil.';
    }
    if (message.contains('already registered')) {
      return 'Bu e-posta adresiyle daha önce hesap oluşturulmuş.';
    }
    return error.message;
  }

  void _showAuthError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
    GlassToast.show(context, message, isError: true);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nickCtrl.dispose();
    super.dispose();
  }

  Future<void> _finishAuthenticatedEntry() async {
    final preview = await gameStore.prepareOfflineProgressMerge();
    if (!mounted) return;

    if (preview != null) {
      final decision = await showOfflineProgressMergeDialog(context, preview);
      if (!mounted || decision == null) return;

      if (decision == ProgressMergeDecision.merge) {
        await gameStore.mergeOfflineProgress(preview);
      } else {
        await gameStore.useCloudProgress(preview);
      }
    }

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
            InviteListenerWrapper(child: HomeScreen(data: gameStore.data!)),
      ),
      (route) => false,
    );
  }

  Future<void> _authenticate() async {
    if (!_formKey.currentState!.validate()) return;

    final client = SupabaseState.client;
    if (client == null) {
      setState(() => _error = 'Çevrimiçi giriş şu anda kullanılamıyor.');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final email = _emailCtrl.text.trim();
      const dummyPassword = 'AutoLoginPass123!';

      if (_isLogin) {
        await client.auth
            .signInWithPassword(email: email, password: dummyPassword)
            .timeout(const Duration(seconds: 20));
      } else {
        gameStore.playerName = _nickCtrl.text.trim();
        await gameStore.prefs.setString('player_name', gameStore.playerName);

        await client.auth
            .signUp(email: email, password: dummyPassword)
            .timeout(const Duration(seconds: 20));
      }

      if (!mounted) return;

      if (client.auth.currentSession != null) {
        _finishAuthenticatedEntry();
      } else {
        _showAuthError('Giriş yapılamadı. E-posta onayı gerekiyor olabilir.');
      }
    } on AuthException catch (e) {
      _showAuthError('İşlem başarısız: ${_friendlyAuthError(e)}');
    } on TimeoutException {
      _showAuthError(
        'İstek zaman aşımına uğradı. İnternet bağlantını kontrol et.',
      );
    } catch (e) {
      _showAuthError('Beklenmeyen bir hata oluştu.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF080F1A),
      child: Stack(
        children: [
          // Exact same background as AuthScreen
          Positioned.fill(
            child: Image.asset(
              'assets/branding/auth_bg.png',
              fit: BoxFit.cover,
            ),
          ),
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

          Positioned.fill(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top App Bar Area
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                      child: Row(
                        children: [
                          // Liquid Glass Back Button - Round
                          ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                  tooltip: 'Geri Dön',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(
                          left: 32,
                          right: 32,
                          top: 24,
                          bottom: 120,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 20),

                            Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Sliding Tab Bar
                                  _SlidingTabBar(
                                    isLogin: _isLogin,
                                    onChanged: (isLogin) {
                                      setState(() {
                                        _isLogin = isLogin;
                                        _error = '';
                                      });
                                    },
                                  ),

                                  const SizedBox(height: 40),

                                  // Unified Animated Form
                                  _buildUnifiedForm(),

                                  if (_error.isNotEmpty) ...[
                                    const SizedBox(height: 24),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.redAccent.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        _error,
                                        style: const TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 14,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ), // End of SafeArea
            ), // End of Scaffold
          ), // End of Positioned.fill
        ],
      ),
    );
  }

  Widget _buildUnifiedForm() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CustomInput(
            key: const ValueKey('email'),
            controller: _emailCtrl,
            hint: 'E-posta Adresi',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) => (v == null || v.isEmpty || !v.contains('@'))
                ? 'Geçerli bir e-posta girin.'
                : null,
          ),

          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isLogin
                ? const SizedBox(height: 0)
                : Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: _CustomInput(
                      key: const ValueKey('reg_nick'),
                      controller: _nickCtrl,
                      hint: 'Oyun İçi Adın',
                      icon: Icons.person_outline_rounded,
                      validator: (v) => (v == null || v.trim().length < 3)
                          ? 'En az 3 karakter olmalı.'
                          : null,
                    ),
                  ),
          ),

          const SizedBox(height: 32),

          // Button
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _isLogin
                ? _TransparentActionButton(
                    key: const ValueKey('login'),
                    label: _loading ? 'BEKLEYİN...' : 'GİRİŞ YAP',
                    icon: Icons.login_rounded,
                    onPressed: _loading ? null : _authenticate,
                  )
                : _TransparentActionButton(
                    key: const ValueKey('reg'),
                    label: _loading ? 'BEKLEYİN...' : 'KAYIT OL',
                    icon: Icons.person_add_rounded,
                    onPressed: _loading ? null : _authenticate,
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── SlidingTabBar ────────────────────────────────────────────────────────
class _SlidingTabBar extends StatefulWidget {
  final bool isLogin;
  final ValueChanged<bool> onChanged;

  const _SlidingTabBar({required this.isLogin, required this.onChanged});

  @override
  State<_SlidingTabBar> createState() => _SlidingTabBarState();
}

class _SlidingTabBarState extends State<_SlidingTabBar> {
  double? _dragPosition;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / 2;

          double leftPos = widget.isLogin ? 0 : tabWidth;
          if (_dragPosition != null) {
            leftPos = _dragPosition!.clamp(0.0, tabWidth);
          }

          final textStyle = TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            fontFamily: GoogleFonts.oswald().fontFamily,
            letterSpacing: 0.5,
          );

          return TweenAnimationBuilder<double>(
            tween: Tween<double>(end: leftPos),
            duration: _dragPosition != null
                ? Duration.zero
                : const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            builder: (context, currentLeft, child) {
              return Stack(
                children: [
                  // 1. Alt Katman (Sabit Beyaz Yazılar)
                  Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: Text(
                            'Giriş Yap',
                            style: textStyle.copyWith(color: Colors.white70),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Kayıt Ol',
                            style: textStyle.copyWith(color: Colors.white70),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 2. Üst Katman (Kayan Beyaz Kapsül ve İçindeki Siyah Yazılar)
                  Positioned(
                    left: currentLeft,
                    top: 0,
                    bottom: 0,
                    width: tabWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Stack(
                          children: [
                            Positioned(
                              left:
                                  -currentLeft, // Kapsül sağa kaydıkça yazıyı sola çek ki sabit kalsın!
                              top: 0,
                              bottom: 0,
                              width: constraints.maxWidth,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Center(
                                      child: Text(
                                        'Giriş Yap',
                                        style: textStyle.copyWith(
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Center(
                                      child: Text(
                                        'Kayıt Ol',
                                        style: textStyle.copyWith(
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 3. Etkileşim Katmanı
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) {
                        final isLoginTarget =
                            details.localPosition.dx < tabWidth;
                        if (isLoginTarget != widget.isLogin) {
                          widget.onChanged(isLoginTarget);
                        }
                      },
                      onHorizontalDragStart: (details) {
                        setState(
                          () => _dragPosition = widget.isLogin ? 0.0 : tabWidth,
                        );
                      },
                      onHorizontalDragUpdate: (details) {
                        if (_dragPosition != null) {
                          setState(
                            () => _dragPosition =
                                _dragPosition! + details.delta.dx,
                          );
                        }
                      },
                      onHorizontalDragEnd: (details) {
                        if (_dragPosition != null) {
                          final isLoginTarget = _dragPosition! < (tabWidth / 2);
                          setState(() => _dragPosition = null);
                          if (isLoginTarget != widget.isLogin) {
                            widget.onChanged(isLoginTarget);
                          }
                        }
                      },
                      onHorizontalDragCancel: () {
                        if (_dragPosition != null) {
                          setState(() => _dragPosition = null);
                        }
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ─── TransparentActionButton ───────────────────────────────────────────────
class _TransparentActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _TransparentActionButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
  });

  @override
  State<_TransparentActionButton> createState() =>
      _TransparentActionButtonState();
}

class _TransparentActionButtonState extends State<_TransparentActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool disabled = widget.onPressed == null;
    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: disabled
          ? null
          : (_) {
              setState(() => _pressed = false);
              gameStore.tap();
              widget.onPressed!();
            },
      onTapCancel: disabled ? null : () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Opacity(
          opacity: disabled ? 0.5 : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white38, width: 1.0),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── CustomInput ──────────────────────────────────────────────────────────
class _CustomInput extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _CustomInput({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  State<_CustomInput> createState() => _CustomInputState();
}

class _CustomInputState extends State<_CustomInput> {
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      validator: widget.validator,
      builder: (state) {
        // Hata varsa ve odaklanılmamışsa kırmızı yap. Odaklanınca normale dönsün.
        final hasError = state.hasError && !_focus;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Focus(
              onFocusChange: (f) => setState(() => _focus = f),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: _focus ? 15 : 8,
                    sigmaY: _focus ? 15 : 8,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: _focus ? 0.15 : 0.05,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: hasError
                            ? Colors.redAccent
                            : (_focus
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.3)),
                        width: hasError ? 1.0 : (_focus ? 1.5 : 1.0),
                      ),
                      boxShadow: _focus
                          ? [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.1),
                                blurRadius: 10,
                              ),
                            ]
                          : [],
                    ),
                    child: TextField(
                      controller: widget.controller,
                      keyboardType: widget.keyboardType,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      cursorColor: Colors.white,
                      onChanged: (val) {
                        state.didChange(val);
                        if (state.hasError) {
                          state
                              .validate(); // Düzeltildiğinde hatayı anında silmek için
                        }
                      },
                      decoration: InputDecoration(
                        filled: false,
                        border: InputBorder.none,
                        hintText: widget.hint,
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 16,
                        ),
                        prefixIcon: Icon(
                          widget.icon,
                          color: hasError
                              ? Colors.redAccent
                              : (_focus ? Colors.white : Colors.white70),
                          size: 22,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 18,
                          horizontal: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Hata Mesajı (Blur'un dışında)
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              alignment: Alignment.topCenter,
              curve: Curves.easeOut,
              child: hasError
                  ? Padding(
                      padding: const EdgeInsets.only(left: 20, top: 6),
                      child: Text(
                        state.errorText ?? '',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity, height: 0),
            ),
          ],
        );
      },
    );
  }
}

