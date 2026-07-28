import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'online/supabase_online_game.dart';
import 'globals.dart';
import 'constants.dart';
import 'screens/home_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'models/game_data.dart';
import 'models/multi_league.dart';
import 'widgets/common_widgets.dart';
import 'services/invite_service.dart';
import 'widgets/invite_overlay.dart';
import 'services/supabase_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env", isOptional: true);
  await gameStore.load();
  final previousFlutterError = FlutterError.onError;
  FlutterError.onError = (details) {
    unawaited(
      diagnostics.record(
        level: 'error',
        event: 'flutter_framework_error',
        errorCode: 'FM-SYS-002',
        metadata: {'kind': details.exception.runtimeType.toString()},
      ),
    );
    previousFlutterError?.call(details);
  };
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(
      diagnostics.record(
        level: 'error',
        event: 'unhandled_async_error',
        errorCode: 'FM-SYS-002',
        metadata: {'kind': error.runtimeType.toString()},
      ),
    );
    return false;
  };
  if (SupabaseOnlineGameRepository.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseOnlineGameRepository.projectUrl,
        publishableKey: SupabaseOnlineGameRepository.publishableKey,
      );
      supabaseReady = true;
      // InviteService başlat
      final client = SupabaseState.client;

      if (client != null) {
        inviteService = InviteService(client);
        inviteService!.startListening();
      }
    } catch (error) {
      supabaseReady = false;
      await diagnostics.record(
        level: 'warning',
        event: 'supabase_initialization_failed',
        errorCode: 'FM-SYS-001',
        metadata: {'kind': error.runtimeType.toString()},
      );
    }
  }
  runApp(const FutbolMeydaniApp());
}

class FutbolMeydaniApp extends StatelessWidget {
  const FutbolMeydaniApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: navigatorKey,
    title: 'Futbol Meydanı',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: green,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    ),
    home: const DataLoader(),
  );
}

class DataLoader extends StatelessWidget {
  const DataLoader({super.key});

  Future<GameData> load() async {
    final rawFuture = Future.wait([
      rootBundle.loadString('assets/data/futbol_hedefi_2024_25.json'),
      rootBundle.loadString('assets/data/meydan_2023_24.json'),
    ]);
    await Future.delayed(
      Duration(milliseconds: gameStore.animations ? 3400 : 450),
    );
    final raw = await rawFuture;
    final legacy = GameData.fromJson(
      jsonDecode(raw[0]) as Map<String, dynamic>,
    );
    return legacy.withMultiLeague(
      MultiLeagueData.fromJson(jsonDecode(raw[1]) as Map<String, dynamic>),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<GameData>(
    future: load(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return ErrorView(message: '${snapshot.error}');
      }

      if (!snapshot.hasData) {
        return const BrandedSplash();
      }

      gameStore.data = snapshot.data!;
      final client = SupabaseState.client;

      if (client == null) {
        // Supabase yoksa çevrimdışı oyunlar kullanılabilir.
        return HomeScreen(data: snapshot.data!);
      }

      final session = client.auth.currentSession;

      if (session != null) {
        return InviteListenerWrapper(child: HomeScreen(data: snapshot.data!));
      }

      return const OnboardingScreen();
    },
  );
}

class BrandedSplash extends StatefulWidget {
  const BrandedSplash({super.key});
  @override
  State<BrandedSplash> createState() => _BrandedSplashState();
}

class _BrandedSplashState extends State<BrandedSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: gameStore.animations ? 3200 : 300),
    )..forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  double phase(double start, double end) =>
      ((controller.value - start) / (end - start)).clamp(0.0, 1.0).toDouble();
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -.25),
          radius: 1.1,
          colors: [Color(0xFF174D37), Color(0xFF04110C), bg],
        ),
      ),
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, _) {
          final fall = Curves.easeOutBack.transform(phase(0, .43));
          final impact = Curves.easeOut.transform(phase(.38, .62));
          final reveal = Curves.easeInOutCubic.transform(phase(.46, .82));
          final words = Curves.easeOut.transform(phase(.76, 1));
          final ballFade = 1 - phase(.48, .68);
          final ringOpacity = sin(pi * impact).clamp(0.0, 1.0).toDouble();
          final travel = -MediaQuery.sizeOf(context).height * .58 * (1 - fall);
          return SizedBox.expand(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: ringOpacity,
                  child: Transform.scale(
                    scale: .7 + impact * 2.7,
                    child: Container(
                      width: 115,
                      height: 115,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: green.withValues(alpha: .75),
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                ),
                Opacity(
                  opacity: reveal,
                  child: Transform.scale(
                    scale: .72 + reveal * .28,
                    child: Container(
                      width: 205,
                      height: 205,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(46),
                        boxShadow: [
                          BoxShadow(
                            color: green.withValues(alpha: .34 * reveal),
                            blurRadius: 52,
                            spreadRadius: 7,
                          ),
                        ],
                      ),
                      child: ClipPath(
                        clipper: LogoRevealClipper(reveal),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(46),
                          child: Image.asset(
                            'assets/branding/app_icon.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Opacity(
                  opacity: ballFade.clamp(0.0, 1.0).toDouble(),
                  child: Transform.translate(
                    offset: Offset(0, travel),
                    child: Transform.rotate(
                      angle: controller.value * pi * 10,
                      child: Transform.scale(
                        scale: .72 + fall * .38 + impact * .18,
                        child: const Icon(
                          Icons.sports_soccer,
                          size: 78,
                          color: Colors.white,
                          shadows: [
                            Shadow(color: Color(0xCC71F39A), blurRadius: 22),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, 155),
                  child: Opacity(
                    opacity: words,
                    child: Transform.translate(
                      offset: Offset(0, 18 * (1 - words)),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'FUTBOL MEYDANI',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.7,
                            ),
                          ),
                          SizedBox(height: 7),
                          Text(
                            'BİLGİNİ SAHAYA ÇIKAR',
                            style: TextStyle(
                              color: green,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.1,
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
        },
      ),
    ),
  );
}

class LogoRevealClipper extends CustomClipper<Path> {
  const LogoRevealClipper(this.progress);
  final double progress;
  @override
  Path getClip(Size size) {
    final radius =
        sqrt(size.width * size.width + size.height * size.height) *
        .55 *
        progress;
    return Path()..addOval(
      Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: radius,
      ),
    );
  }

  @override
  bool shouldReclip(covariant LogoRevealClipper oldClipper) =>
      oldClipper.progress != progress;
}
