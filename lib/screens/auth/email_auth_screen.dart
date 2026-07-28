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
  final _otpCtrl = TextEditingController();

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
    _otpCtrl.dispose();
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

  Future<void> _sendOtp() async {
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
      if (!_isLogin) {
        // Kayıt olurken yerel ismi kaydet
        gameStore.playerName = _nickCtrl.text.trim();
        await gameStore.prefs.setString('player_name', gameStore.playerName);
      }

      await client.auth
          .signInWithOtp(email: _emailCtrl.text.trim())
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;
      _showOtpBottomSheet();
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

  void _showOtpBottomSheet() {
    _otpCtrl.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _OtpBottomSheet(
        email: _emailCtrl.text.trim(),
        otpCtrl: _otpCtrl,
        onVerify: (code) => _verifyOtp(code),
      ),
    ).then((_) {
      if (SupabaseState.client?.auth.currentSession != null) {
        _finishAuthenticatedEntry();
      }
    });
  }

  Future<bool> _verifyOtp(String code) async {
    final client = SupabaseState.client;
    if (client == null) return false;

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final res = await client.auth
          .verifyOTP(
            type: OtpType.email,
            token: code,
            email: _emailCtrl.text.trim(),
          )
          .timeout(const Duration(seconds: 20));

      if (res.session != null) {
        return true;
      } else {
        _showAuthError('Doğrulama başarısız.');
        return false;
      }
    } on AuthException catch (e) {
      _showAuthError('Kod hatalı veya süresi dolmuş: ${_friendlyAuthError(e)}');
      return false;
    } on TimeoutException {
      _showAuthError('İstek zaman aşımına uğradı.');
      return false;
    } catch (e) {
      _showAuthError('Doğrulama sırasında hata oluştu.');
      return false;
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
                    label: _loading ? 'BEKLEYİN...' : 'KOD GÖNDER',
                    icon: Icons.mark_email_unread_outlined,
                    onPressed: _loading ? null : _sendOtp,
                  )
                : _TransparentActionButton(
                    key: const ValueKey('reg'),
                    label: _loading ? 'BEKLEYİN...' : 'KAYIT OL',
                    icon: Icons.person_add_rounded,
                    onPressed: _loading ? null : _sendOtp,
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

class _OtpBottomSheet extends StatefulWidget {
  final String email;
  final TextEditingController otpCtrl;
  final Future<bool> Function(String) onVerify;

  const _OtpBottomSheet({
    required this.email,
    required this.otpCtrl,
    required this.onVerify,
  });

  @override
  State<_OtpBottomSheet> createState() => _OtpBottomSheetState();
}

class _OtpBottomSheetState extends State<_OtpBottomSheet> {
  bool _isLoading = false;
  bool _isSuccess = false;
  Timer? _resendTimer;
  int _countdown = 180;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() => _countdown = 180);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _resendCode() async {
    if (_countdown > 0) return;

    GlassToast.show(
      context,
      '${widget.email} adresine yeni kod gönderiliyor...',
      isError: false,
    );

    try {
      await SupabaseState.client?.auth.signInWithOtp(email: widget.email);
      _startTimer();
      if (mounted) {
        GlassToast.show(
          context,
          'Yeni kod gönderildi! Lütfen mailinizi kontrol edin.',
          isError: false,
        );
      }
    } catch (e) {
      if (mounted) {
        GlassToast.show(
          context,
          'Kod gönderilirken bir hata oluştu.',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSuccess) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(48)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            height: 350,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: Colors.greenAccent,
                    size: 120,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Giriş Başarılı!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(48)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
          ),
          padding: EdgeInsets.only(
            left: 32,
            right: 32,
            top: 40,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 40,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'DOĞRULAMA KODU',
                style: GoogleFonts.oswald(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                '${widget.email}\nadresine gönderdiğimiz 6 haneli kodu girin.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.transparent, // Siyahlık tamamen kaldırıldı
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withValues(
                          alpha: 0.1,
                        ), // Beyazımsı cam hat
                      ),
                    ),
                    child: TextField(
                      controller: widget.otpCtrl,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      enabled: !_isLoading,
                      style: GoogleFonts.oswald(
                        color: Colors.white,
                        fontSize: 36,
                        letterSpacing: 24,
                        fontWeight: FontWeight.w500,
                      ),
                      cursorColor: Colors.white,
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '000000',
                        hintStyle: GoogleFonts.oswald(
                          color: Colors.white.withValues(alpha: 0.1),
                          fontSize: 36,
                          letterSpacing: 24,
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                        filled: false,
                        fillColor: Colors.transparent,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _TransparentActionButton(
                label: _isLoading ? 'DOĞRULANIYOR...' : 'ONAYLA',
                icon: Icons.check_circle_outline_rounded,
                onPressed: _isLoading
                    ? null
                    : () async {
                        if (widget.otpCtrl.text.length != 6) {
                          if (mounted) {
                            GlassToast.show(
                              context,
                              'Lütfen 6 haneli kodu eksiksiz girin.',
                              isError: true,
                            );
                          }
                          return;
                        }
                        setState(() => _isLoading = true);
                        final success = await widget.onVerify(
                          widget.otpCtrl.text,
                        );
                        if (success && mounted) {
                          setState(() {
                            _isLoading = false;
                            _isSuccess = true;
                          });
                          // Wait for animation to finish
                          await Future.delayed(
                            const Duration(milliseconds: 2500),
                          );
                          if (mounted) Navigator.pop(context);
                        } else if (mounted) {
                          setState(() => _isLoading = false);
                        }
                      },
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _countdown == 0 ? () => _resendCode() : null,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white38,
                ),
                child: Text(
                  _countdown > 0
                      ? 'Yeniden Gönder ($_countdown sn)'
                      : 'Kodu Yeniden Gönder',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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
