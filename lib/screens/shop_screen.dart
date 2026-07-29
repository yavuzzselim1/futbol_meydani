import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:futbol_meydani/constants.dart';
import 'package:futbol_meydani/globals.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:futbol_meydani/services/game_store.dart';
import 'package:futbol_meydani/utils/glass_toast.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with TickerProviderStateMixin {
  int _selectedCategoryIndex = 0;
  late PageController _pageController;
  double _pageOffset = 0.0;

  final List<String> _categories = ['AVATARLAR', 'TEMALAR', 'GÜÇLER'];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.70);
    _pageController.addListener(() {
      setState(() {
        _pageOffset = _pageController.page ?? 0.0;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _currentItems {
    if (_selectedCategoryIndex == 0) return GameStore.avatars;
    if (_selectedCategoryIndex == 1) return GameStore.themes;
    return GameStore.boosts;
  }

  String _getCategoryKey() {
    if (_selectedCategoryIndex == 0) return 'avatar';
    if (_selectedCategoryIndex == 1) return 'theme';
    return 'boost';
  }

  void _buyItem(Map<String, dynamic> item) {
    final category = _getCategoryKey();
    final id = item['id'] as String;
    final price = item['price'] as int;
    final req = item['requirement'] as String?;

    bool isOwned = false;
    if (category == 'avatar') isOwned = gameStore.unlockedAvatars.contains(id);
    if (category == 'theme') isOwned = gameStore.unlockedThemes.contains(id);
    if (category == 'boost') isOwned = gameStore.unlockedBoosts.contains(id);

    if (isOwned) {
      GlassToast.show(context, '${item['title']} zaten sahipsin!', isError: false);
      return;
    }

    if (req != null) {
      bool reqOwned = false;
      String reqTitle = '';
      if (category == 'avatar') {
        reqOwned = gameStore.unlockedAvatars.contains(req);
        reqTitle = GameStore.avatars.firstWhere((e) => e['id'] == req)['title'];
      }
      if (category == 'theme') {
        reqOwned = gameStore.unlockedThemes.contains(req);
        reqTitle = GameStore.themes.firstWhere((e) => e['id'] == req)['title'];
      }
      if (category == 'boost') {
        reqOwned = gameStore.unlockedBoosts.contains(req);
        reqTitle = GameStore.boosts.firstWhere((e) => e['id'] == req)['title'];
      }

      if (!reqOwned) {
        gameStore.tap(GameSound.warning);
        GlassToast.show(context, 'Önce $reqTitle satın almalısın!', isError: true);
        return;
      }
    }

    if (gameStore.deductCoins(price)) {
      if (category == 'avatar') gameStore.unlockAvatar(id);
      if (category == 'theme') gameStore.unlockTheme(id);
      if (category == 'boost') gameStore.unlockBoost(id);
      gameStore.tap(GameSound.win);
      GlassToast.show(context, '${item['title']} satın alındı! 🎉', isError: false);
      setState(() {});
    } else {
      gameStore.tap(GameSound.warning);
      GlassToast.show(context, 'Yeterli Meydan Parası yok!', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _currentItems;
    final activeIndex = _pageOffset.round().clamp(0, items.length - 1);
    final activeItem = items[activeIndex];
    final activeColor = activeItem['color'] as Color;

    return AnimatedBuilder(
      animation: gameStore,
      builder: (context, _) => Scaffold(
        backgroundColor: const Color(0xFF030712), // Deep dark elegant background
        body: Stack(
          children: [
            // 1. Dynamic Glassmorphic Ambient Orbs
            Positioned(
              top: -150,
              left: -100,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 700),
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: activeColor.withValues(alpha: 0.15),
                  boxShadow: [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.3),
                      blurRadius: 120,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              right: -50,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 700),
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: activeColor.withValues(alpha: 0.1),
                  boxShadow: [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.2),
                      blurRadius: 100,
                    ),
                  ],
                ),
              ),
            ),
            // Glass overlay to blend everything perfectly
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: const SizedBox(),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  // 2. Premium Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'MAĞAZA',
                          style: GoogleFonts.oswald(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                            shadows: [
                              Shadow(
                                color: activeColor.withValues(alpha: 0.8),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                        ),
                        // Glass Coin Balance
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.monetization_on_rounded,
                                    color: Color(0xFF71F39A),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${gameStore.coins}',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. Smooth Segmented Control for Categories
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Container(
                      height: 55,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: List.generate(_categories.length, (index) {
                          final isSel = _selectedCategoryIndex == index;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                gameStore.tap(GameSound.tap);
                                setState(() {
                                  _selectedCategoryIndex = index;
                                  if (_pageController.hasClients) {
                                    _pageController.jumpToPage(0);
                                  }
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(22),
                                  boxShadow: isSel
                                      ? [
                                          BoxShadow(
                                            color: Colors.white.withValues(alpha: 0.3),
                                            blurRadius: 10,
                                            offset: const Offset(0, 2),
                                          )
                                        ]
                                      : [],
                                ),
                                child: Center(
                                  child: Text(
                                    _categories[index],
                                    style: GoogleFonts.oswald(
                                      color: isSel ? Colors.black : Colors.white70,
                                      fontSize: 16,
                                      fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 4. 3D Glassmorphic Cards Carousel
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const BouncingScrollPhysics(),
                      itemCount: items.length,
                      onPageChanged: (index) {
                        gameStore.tap(GameSound.tap);
                      },
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final color = item['color'] as Color;
                        final icon = item['icon'] as IconData?;
                        final imagePath = item['imagePath'] as String?;

                        double diff = index - _pageOffset;
                        double scale = (1 - (diff.abs() * 0.15)).clamp(0.85, 1.0);
                        double opacity = (1 - (diff.abs() * 0.4)).clamp(0.4, 1.0);
                        double rotateY = diff * 0.3; // 3D Tilt effect

                        final catKey = _getCategoryKey();
                        final id = item['id'] as String;
                        final req = item['requirement'] as String?;

                        bool isOwned = false;
                        bool isLocked = false;

                        if (catKey == 'avatar') {
                          isOwned = gameStore.unlockedAvatars.contains(id);
                          if (req != null) isLocked = !gameStore.unlockedAvatars.contains(req);
                        } else if (catKey == 'theme') {
                          isOwned = gameStore.unlockedThemes.contains(id);
                          if (req != null) isLocked = !gameStore.unlockedThemes.contains(req);
                        } else if (catKey == 'boost') {
                          isOwned = gameStore.unlockedBoosts.contains(id);
                          if (req != null) isLocked = !gameStore.unlockedBoosts.contains(req);
                        }

                        return Opacity(
                          opacity: opacity,
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.002) // Perspective
                              ..rotateY(rotateY)
                              ..scale(scale),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 40, top: 20),
                              child: Stack(
                                children: [
                                  // Glass Background
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(40),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(40),
                                          border: Border.all(
                                            color: diff.abs() < 0.2
                                                ? color.withValues(alpha: 0.8)
                                                : Colors.white.withValues(alpha: 0.1),
                                            width: diff.abs() < 0.2 ? 2.0 : 1.0,
                                          ),
                                          boxShadow: [
                                            if (diff.abs() < 0.2)
                                              BoxShadow(
                                                color: color.withValues(alpha: 0.3),
                                                blurRadius: 50,
                                                offset: const Offset(0, 10),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  // Big Glowing Icon behind content
                                  Positioned(
                                    top: 40,
                                    right: -20,
                                    child: imagePath != null 
                                      ? Opacity(
                                          opacity: 0.15,
                                          child: ClipOval(child: Image.asset(imagePath, width: 160, height: 160, fit: BoxFit.cover)),
                                        )
                                      : Icon(
                                          icon,
                                          size: 160,
                                          color: color.withValues(alpha: 0.15),
                                        ),
                                  ),

                                  // Content
                                  Padding(
                                    padding: const EdgeInsets.all(28.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header Icon & Title
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.2),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: color.withValues(alpha: 0.4),
                                                blurRadius: 20,
                                              ),
                                            ],
                                          ),
                                          child: imagePath != null
                                              ? ClipOval(child: Image.asset(imagePath, width: 40, height: 40, fit: BoxFit.cover))
                                              : Icon(icon, color: Colors.white, size: 40),
                                        ),
                                        const SizedBox(height: 24),
                                        Expanded(
                                          child: SingleChildScrollView(
                                            physics: const BouncingScrollPhysics(),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item['title'],
                                                  style: GoogleFonts.oswald(
                                                    color: Colors.white,
                                                    fontSize: 32,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 1.2,
                                                    height: 1.1,
                                                    shadows: [
                                                      Shadow(
                                                        color: color.withValues(alpha: 0.5),
                                                        blurRadius: 15,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                Text(
                                                  item['desc'],
                                                  style: GoogleFonts.inter(
                                                    color: Colors.white70,
                                                    fontSize: 15,
                                                    height: 1.4,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        
                                        // 5. Dynamic Buy/Status Button
                                        const SizedBox(height: 16),
                                        _buildActionBtn(diff, isOwned, isLocked, item, color),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 100), // Space for bottom nav
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn(double diff, bool isOwned, bool isLocked, Map<String, dynamic> item, Color color) {
    if (isOwned) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Center(
          child: Text(
            'KOLEKSİYONDA',
            style: GoogleFonts.oswald(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
      );
    }
    
    return GestureDetector(
      onTap: diff.abs() < 0.2 && !isLocked ? () => _buyItem(item) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: diff.abs() < 0.2 && !isLocked
                ? [color, color.withValues(alpha: 0.8)]
                : [Colors.white12, Colors.white10],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: diff.abs() < 0.2 && !isLocked
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.6),
                    blurRadius: 25,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isLocked ? Icons.lock_rounded : Icons.monetization_on_rounded,
              color: diff.abs() < 0.2 && !isLocked ? Colors.black87 : Colors.white54,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              isLocked ? 'KİLİTLİ' : '${item['price']} MP İLE AL',
              style: GoogleFonts.oswald(
                color: diff.abs() < 0.2 && !isLocked ? Colors.black87 : Colors.white54,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
