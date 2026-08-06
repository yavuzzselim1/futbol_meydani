import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:futbol_meydani/utils/glass_toast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:futbol_meydani/constants.dart';
import 'package:futbol_meydani/globals.dart';
import 'package:futbol_meydani/models/progress_merge.dart';
import 'package:futbol_meydani/widgets/offline_progress_merge_dialog.dart';
import 'package:futbol_meydani/widgets/invite_overlay.dart';
import '../home_screen.dart';

import '../../services/supabase_state.dart';

enum _AuthStep { email, otp, nickname }

class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  _AuthStep _step = _AuthStep.email;
  bool _loading = false;
  String _error = '';
  int _resendCooldown = 0;
  Timer? _resendTimer;

  final _emailFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _nickFormKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _nickCtrl = TextEditingController();

  String _friendlyAuthError(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid api key')) {
      return 'Supabase anahtarı geçersiz veya proje adresiyle eşleşmiyor. '
          'Publishable key ve SUPABASE_URL değerlerini kontrol et.';
    }
    if (message.contains('token has expired') || message.contains('invalid')) {
      return 'Kod hatalı veya süresi dolmuş. Yeni bir kod iste.';
    }
    if (message.contains('for security purposes') || message.contains('rate limit')) {
      return 'Çok sık denedin. Birkaç saniye sonra tekrar dene.';
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
    _otpCtrl.dispose();
    _nickCtrl.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendCooldown = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown--);
      }
    });
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

  Future<bool> _hasExistingProfile(String userId) async {
    final client = SupabaseState.client;
    if (client == null) return false;
    try {
      final res = await client
          .from('online_profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      return res != null;
    } catch (_) {
      // Belirsiz durumda kayıt ekranını atlayıp mevcut akışa güveniyoruz;
      // syncProfile zaten eksik profili gerektiğinde oluşturur.
      return true;
    }
  }

  Future<void> _sendOtp() async {
    if (!_emailFormKey.currentState!.validate()) return;

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
      final res = await client.functions
          .invoke('send-otp', body: {'email': email})
          .timeout(const Duration(seconds: 30));

      final data = res.data;
      final ok = data is Map && data['ok'] == true;
      if (!ok) {
        final message = (data is Map ? data['error'] as String? : null) ??
            'Kod gönderilemedi. Tekrar dene.';
        _showAuthError(message);
        return;
      }

      if (!mounted) return;
      setState(() => _step = _AuthStep.otp);
      _startResendCooldown();
      GlassToast.show(context, 'Doğrulama kodu e-postana gönderildi.');
    } on FunctionException catch (e) {
      final body = e.details;
      final message = (body is Map ? body['error'] as String? : null) ??
          'Kod gönderilemedi. Tekrar dene.';
      _showAuthError(message);
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

  Future<void> _verifyOtp() async {
    if (!_otpFormKey.currentState!.validate()) return;

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
      final code = _otpCtrl.text.trim();

      final res = await client.functions
          .invoke('verify-otp', body: {'email': email, 'code': code})
          .timeout(const Duration(seconds: 20));

      final data = res.data;
      final hashedToken =
          (data is Map && data['ok'] == true) ? data['hashed_token'] as String? : null;
      if (hashedToken == null) {
        final message = (data is Map ? data['error'] as String? : null) ??
            'Kod doğrulanamadı. Tekrar dene.';
        _showAuthError(message);
        return;
      }

      await client.auth
          .verifyOTP(email: email, token: hashedToken, type: OtpType.magiclink)
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      final user = client.auth.currentUser;
      if (user == null) {
        _showAuthError('Giriş doğrulanamadı. Kodu tekrar dene.');
        return;
      }

      final hasProfile = await _hasExistingProfile(user.id);
      if (!mounted) return;

      if (hasProfile) {
        await _finishAuthenticatedEntry();
      } else {
        setState(() => _step = _AuthStep.nickname);
      }
    } on FunctionException catch (e) {
      final body = e.details;
      final message = (body is Map ? body['error'] as String? : null) ??
          'Kod doğrulanamadı. Tekrar dene.';
      _showAuthError(message);
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

  Future<void> _confirmNickname() async {
    if (!_nickFormKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      gameStore.playerName = _nickCtrl.text.trim();
      await gameStore.prefs.setString('player_name', gameStore.playerName);
      await _finishAuthenticatedEntry();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _backToEmailStep() {
    _resendTimer?.cancel();
    setState(() {
      _step = _AuthStep.email;
      _otpCtrl.clear();
      _error = '';
      _resendCooldown = 0;
    });
  }

  void _onBackPressed() {
    if (_step == _AuthStep.email) {
      Navigator.pop(context);
    } else if (_step == _AuthStep.otp) {
      _backToEmailStep();
    }
    // Nickname adımında geri tuşu gösterilmiyor (giriş zaten tamamlandı).
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF080F1A),
      child: Stack(
        children: [
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
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                      child: Row(
                        children: [
                          if (_step != _AuthStep.nickname)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    onPressed: _onBackPressed,
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
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, anim) =>
                                  FadeTransition(opacity: anim, child: child),
                              child: _buildStepContent(),
                            ),
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
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case _AuthStep.email:
        return _buildEmailStep(key: const ValueKey('email_step'));
      case _AuthStep.otp:
        return _buildOtpStep(key: const ValueKey('otp_step'));
      case _AuthStep.nickname:
        return _buildNicknameStep(key: const ValueKey('nickname_step'));
    }
  }

  Widget _buildEmailStep({Key? key}) {
    return Form(
      key: _emailFormKey,
      child: Column(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'GİRİŞ YAP / KAYIT OL',
            textAlign: TextAlign.center,
            style: GoogleFonts.oswald(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'E-postana tek kullanımlık bir doğrulama kodu göndereceğiz. Şifre gerekmiyor.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 32),
          _CustomInput(
            controller: _emailCtrl,
            hint: 'E-posta Adresi',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) => (v == null || v.isEmpty || !v.contains('@'))
                ? 'Geçerli bir e-posta girin.'
                : null,
          ),
          const SizedBox(height: 32),
          _TransparentActionButton(
            label: _loading ? 'BEKLEYİN...' : 'KOD GÖNDER',
            icon: Icons.send_rounded,
            onPressed: _loading ? null : _sendOtp,
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep({Key? key}) {
    return Form(
      key: _otpFormKey,
      child: Column(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'KODU GİR',
            textAlign: TextAlign.center,
            style: GoogleFonts.oswald(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_emailCtrl.text.trim()} adresine gönderilen 6 haneli kodu gir.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 32),
          _CustomInput(
            controller: _otpCtrl,
            hint: '••••••',
            icon: Icons.pin_outlined,
            keyboardType: TextInputType.number,
            validator: (v) => (v == null || v.trim().length != 6)
                ? '6 haneli kodu eksiksiz gir.'
                : null,
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: (_resendCooldown > 0 || _loading) ? null : _sendOtp,
              child: Text(
                _resendCooldown > 0
                    ? 'Kodu tekrar gönder ($_resendCooldown sn)'
                    : 'Kodu tekrar gönder',
                style: TextStyle(
                  color: _resendCooldown > 0 ? Colors.white38 : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _TransparentActionButton(
            label: _loading ? 'BEKLEYİN...' : 'DOĞRULA',
            icon: Icons.check_circle_outline_rounded,
            onPressed: _loading ? null : _verifyOtp,
          ),
        ],
      ),
    );
  }

  Widget _buildNicknameStep({Key? key}) {
    return Form(
      key: _nickFormKey,
      child: Column(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'OYUN İÇİ ADIN',
            textAlign: TextAlign.center,
            style: GoogleFonts.oswald(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Giriş başarılı! Son bir adım: seni sahada nasıl görelim?',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 32),
          _CustomInput(
            controller: _nickCtrl,
            hint: 'Oyun İçi Adın',
            icon: Icons.person_outline_rounded,
            validator: (v) => (v == null || v.trim().length < 3)
                ? 'En az 3 karakter olmalı.'
                : null,
          ),
          const SizedBox(height: 32),
          _TransparentActionButton(
            label: _loading ? 'BEKLEYİN...' : 'MEYDANA ÇIK',
            icon: Icons.sports_soccer_rounded,
            onPressed: _loading ? null : _confirmNickname,
          ),
        ],
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
                          state.validate();
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
