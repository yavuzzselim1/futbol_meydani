import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:futbol_meydani/models/game_data.dart';
import 'package:futbol_meydani/utils/helpers.dart';
import 'package:futbol_meydani/widgets/common_widgets.dart';
import 'package:futbol_meydani/screens/match_screen.dart';
import 'package:futbol_meydani/utils/glass_toast.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.data});
  final GameData data;
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> with SingleTickerProviderStateMixin {
  final _one = TextEditingController();
  final _two = TextEditingController();
  final _focusOne = FocusNode();
  final _focusTwo = FocusNode();
  int _rounds = 5;
  late AnimationController _anim;
  late Animation<double> _slide;
  late Animation<double> _scaleAnim;
  late Animation<double> _blurAnim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _slide = CurvedAnimation(
      parent: _anim,
      curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic),
    );
    _scaleAnim = Tween<double>(begin: 1.25, end: 1.0).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic),
    );
    _blurAnim = Tween<double>(begin: 0.1, end: 25.0).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutQuad),
    );
    _anim.forward();
    _focusOne.addListener(() => setState(() {}));
    _focusTwo.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _one.dispose();
    _two.dispose();
    _focusOne.dispose();
    _focusTwo.dispose();
    _anim.dispose();
    super.dispose();
  }

  void _start() {
    final a = _one.text.trim(), b = _two.text.trim();
    if (a.isEmpty || b.isEmpty || normalize(a) == normalize(b)) {
      GlassToast.show(context, 'İki farklı oyuncu adı yaz.', isError: true);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MatchScreen(data: widget.data, names: [a, b], roundCount: _rounds),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'KARŞILIKLI MEYDAN',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: _anim,
        builder: (context, child) {
          final scaleVal = _scaleAnim.value;
          final blurVal = _blurAnim.value;
          return Stack(
            fit: StackFit.expand,
            children: [
              // Clipped background stack (ClipRect prevents scaled image from overflowing screen bounds during transitions)
              ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: blurVal, sigmaY: blurVal),
                      child: Transform.scale(
                        scale: scaleVal,
                        child: Image.asset(
                          'assets/branding/setup_bg.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Container(
                      color: Colors.black.withOpacity(0.45 * (blurVal / 25.0).clamp(0.0, 1.0)),
                    ),
                  ],
                ),
              ),
              // Content — slide in from bottom
              child!,
            ],
          );
        },
        child: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(_slide),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 28),

                    // ── Oyuncu 1 ────────────────────────────
                    _buildPlayerSlot(
                      controller: _one,
                      focusNode: _focusOne,
                      number: 1,
                      accentColor: const Color(0xFF5EC8FF),
                      nextFocus: _focusTwo,
                    ),

                    const SizedBox(height: 10),

                    // ── VS ───────────────────────────────────
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.white.withOpacity(0.12))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'VS',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 4,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.white.withOpacity(0.12))),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // ── Oyuncu 2 ────────────────────────────
                    _buildPlayerSlot(
                      controller: _two,
                      focusNode: _focusTwo,
                      number: 2,
                      accentColor: const Color(0xFFFFD166),
                      nextFocus: null,
                      onSubmitted: _start,
                    ),

                    const SizedBox(height: 32),

                    // ── Tur Sayısı ───────────────────────────
                    const Text(
                      'TUR SAYISI',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [3, 5, 7].map((n) {
                        final isSelected = _rounds == n;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _rounds = n),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: EdgeInsets.only(right: n != 7 ? 10 : 0),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withOpacity(0.2)
                                    : Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white.withOpacity(0.6)
                                      : Colors.white.withOpacity(0.18),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '$n',
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.55),
                                      fontWeight: FontWeight.w900,
                                      fontSize: isSelected ? 26 : 22,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'TUR',
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white.withOpacity(0.7)
                                          : Colors.white.withOpacity(0.35),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const Spacer(),

                    // ── Maçı Başlat ──────────────────────────
                    GestureDetector(
                      onTap: _start,
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6EF0A0), Color(0xFF00C853)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00C853).withOpacity(0.45),
                              blurRadius: 28,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.sports_soccer_rounded, color: Colors.black, size: 22),
                            SizedBox(width: 10),
                            Text(
                              'MAÇI BAŞLAT',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerSlot({
    required TextEditingController controller,
    required FocusNode focusNode,
    required int number,
    required Color accentColor,
    FocusNode? nextFocus,
    VoidCallback? onSubmitted,
  }) {
    final isFocused = focusNode.hasFocus;
    // BackdropFilter is outside of any fade/slide so blur is instant
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isFocused
                ? accentColor.withOpacity(0.16)
                : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isFocused
                  ? accentColor.withOpacity(0.75)
                  : Colors.white.withOpacity(0.25),
              width: 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(isFocused ? 0.25 : 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: accentColor.withOpacity(isFocused ? 0.7 : 0.35),
                  ),
                ),
                child: Center(
                  child: Text(
                    '$number',
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'OYUNCU $number',
                      style: TextStyle(
                        color: accentColor.withOpacity(isFocused ? 1.0 : 0.7),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: controller,
                      focusNode: focusNode,
                      maxLength: 18,
                      textInputAction: nextFocus != null ? TextInputAction.next : TextInputAction.done,
                      onSubmitted: (_) {
                        if (nextFocus != null) {
                          FocusScope.of(context).requestFocus(nextFocus);
                        } else {
                          onSubmitted?.call();
                        }
                      },
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        height: 1.1,
                      ),
                      decoration: InputDecoration(
                        hintText: 'İsim gir...',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.35),
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                        counterText: '',
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
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
