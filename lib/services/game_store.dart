import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import 'package:futbol_meydani/constants.dart';
import 'package:futbol_meydani/models/game_data.dart';
import 'package:futbol_meydani/models/progress_merge.dart';
import 'progress_merge_service.dart';
import 'supabase_state.dart';

/// Merkezi oyun durumu ve ayar yöneticisi.
/// XP sistemi: maç +50, günlük +75, son dakika golü +100, mükemmel +150 bonus.
class GameStore extends ChangeNotifier {
  bool sound = true, vibration = true, animations = true;
  bool commentator = true, stadiumSounds = true, goalCelebration = true;
  int matchDuration = 3;
  int difficulty = 1;
  String menuTheme = 'system';
  String ballModel = 'classic';
  double hudSize = 1.0;
  bool showPingFps = false;
  bool dataSaver = false;
  int matches = 0, dailyCompleted = 0;
  int lastMinuteBest = 0,
      lastMinuteFurthest = 0,
      lastMinuteGoals = 0,
      lastMinuteBestStreak = 0;
  double bestDifference = -1;
  Map<String, int> wins = {};
  List<int> lastMinuteCareerStars = List.filled(12, 0);
  String playerName = '';

  // Mağaza ve Ekonomi
  int coins = 0;
  int displayCoinsOffset = 0;
  int trophies = 0;
  String friendCode = '';
  int lastDailyRewardTime = 0; // Epoch milliseconds
  List<String> unlockedAvatars = [];
  String currentAvatar = 'default';
  String activeTheme = 'default';
  List<String> unlockedThemes = ['default'];
  List<String> unlockedBoosts = [];

  // Başarım / Rozet Sistemi
  List<String> unlockedBadges = [];

  static final List<Map<String, dynamic>> avatars = [
    {
      'id': 'avatar_pro',
      'title': 'OYUNCU 1',
      'desc': 'İlk oyuncu avatarı',
      'price': 500,
      'imagePath': 'assets/avatars/player_1.png',
      'color': const Color(0xFFFFD166),
      'requirement': null,
    },
    {
      'id': 'avatar_captain',
      'title': 'OYUNCU 2',
      'desc': 'İkinci oyuncu avatarı',
      'price': 750,
      'imagePath': 'assets/avatars/player_2.png',
      'color': const Color(0xFF5EC8FF),
      'requirement': 'avatar_pro',
    },
    {
      'id': 'avatar_legend',
      'title': 'SAHA 1',
      'desc': 'Saha 1 avatarı',
      'price': 1500,
      'imagePath': 'assets/avatars/field_1.png',
      'color': const Color(0xFFFF6B6B),
      'requirement': 'avatar_captain',
    },
    {
      'id': 'avatar_ghost',
      'title': 'SAHA 2',
      'desc': 'Saha 2 avatarı',
      'price': 2000,
      'imagePath': 'assets/avatars/field_2.png',
      'color': const Color(0xFFB388FF),
      'requirement': 'avatar_legend',
    },
  ];

  static final List<Map<String, dynamic>> themes = [
    {
      'id': 'theme_neon',
      'title': 'NEON SAHA',
      'desc': 'Neon ışıklı saha',
      'price': 1200,
      'icon': Icons.stadium_rounded,
      'color': const Color(0xFF5EC8FF),
      'requirement': null,
    },
    {
      'id': 'theme_gold',
      'title': 'ALTIN SAHA',
      'desc': 'Lüks altın kaplama',
      'price': 2000,
      'icon': Icons.star_rounded,
      'color': const Color(0xFFFFD166),
      'requirement': 'theme_neon',
    },
    {
      'id': 'theme_fire',
      'title': 'ATEŞ SAHASI',
      'desc': 'Alevler içinde',
      'price': 1800,
      'icon': Icons.local_fire_department_rounded,
      'color': const Color(0xFFFF6B6B),
      'requirement': 'theme_gold',
    },
    {
      'id': 'theme_ice',
      'title': 'BUZ SAHASI',
      'desc': 'Karlı kış meydanı',
      'price': 1500,
      'icon': Icons.ac_unit_rounded,
      'color': const Color(0xFF80DEEA),
      'requirement': 'theme_fire',
    },
  ];

  static final List<Map<String, dynamic>> boosts = [
    {
      'id': 'boost_xp2x',
      'title': '2X XP',
      'desc': 'Maçlardan +%100 XP kazandırır',
      'price': 200,
      'icon': Icons.bolt_rounded,
      'color': const Color(0xFFFFD166),
      'requirement': null,
    },
    {
      'id': 'boost_coin2x',
      'title': '2X COIN',
      'desc': 'Maçlardan +%100 Coin kazandırır',
      'price': 250,
      'icon': Icons.monetization_on_rounded,
      'color': const Color(0xFF71F39A),
      'requirement': 'boost_xp2x',
    },
    {
      'id': 'boost_reveal',
      'title': 'HIZLI AÇILIŞ',
      'desc': 'Kart açılış hızını ikiye katlar',
      'price': 150,
      'icon': Icons.fast_forward_rounded,
      'color': const Color(0xFF5EC8FF),
      'requirement': 'boost_coin2x',
    },
    {
      'id': 'boost_shield',
      'title': 'KALKAN',
      'desc': 'Kayıplarda kupa düşmesini engeller',
      'price': 300,
      'icon': Icons.shield_rounded,
      'color': const Color(0xFFB388FF),
      'requirement': 'boost_reveal',
    },
  ];

  Color get activeThemeBgColor {
    if (activeTheme == 'theme_neon') return const Color(0xFF0A192F);
    if (activeTheme == 'theme_gold') return const Color(0xFF2C220B);
    if (activeTheme == 'theme_fire') return const Color(0xFF330B0B);
    if (activeTheme == 'theme_ice') return const Color(0xFF0F2537);
    return bg;
  }

  Color get activeThemePanelColor {
    if (activeTheme == 'theme_neon') return const Color(0xFF112240);
    if (activeTheme == 'theme_gold') return const Color(0xFF3E3113);
    if (activeTheme == 'theme_fire') return const Color(0xFF4A1212);
    if (activeTheme == 'theme_ice') return const Color(0xFF1B364A);
    return panel;
  }

  Color get activeThemePanel2Color {
    if (activeTheme == 'theme_neon') return const Color(0xFF172A45);
    if (activeTheme == 'theme_gold') return const Color(0xFF4A3E1B);
    if (activeTheme == 'theme_fire') return const Color(0xFF5E1717);
    if (activeTheme == 'theme_ice') return const Color(0xFF264653);
    return panel2;
  }

  // ── Gerçek XP Sistemi ─────────────────────────────────────────────
  int xp = 0;
  int get level => (xp ~/ 200) + 1;
  int get xpInLevel => xp % 200;
  static const int xpPerLevel = 200;

  // ── Versiyon ─────────────────────────────────────────────────────
  String appVersion = '';

  late SharedPreferences prefs;
  final AudioPlayer audio = AudioPlayer();
  GameData? data; // Loaded JSON data
  bool offlineProgressDirty = false;

  ProgressSnapshot get progressSnapshot => ProgressSnapshot(
    coins: coins,
    xp: xp,
    lastMinuteBest: lastMinuteBest,
    lastMinuteFurthest: lastMinuteFurthest,
    lastMinuteGoals: lastMinuteGoals,
    lastMinuteBestStreak: lastMinuteBestStreak,
    lastMinuteCareerStars: List<int>.from(lastMinuteCareerStars),
    unlockedAvatars: List<String>.from(unlockedAvatars),
    unlockedThemes: List<String>.from(unlockedThemes),
    unlockedBadges: List<String>.from(unlockedBadges),
  );

  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();
    sound = prefs.getBool('sound') ?? true;
    vibration = prefs.getBool('vibration') ?? true;
    animations = prefs.getBool('animations') ?? true;
    commentator = prefs.getBool('commentator') ?? true;
    stadiumSounds = prefs.getBool('stadiumSounds') ?? true;
    goalCelebration = prefs.getBool('goalCelebration') ?? true;
    matchDuration = prefs.getInt('matchDuration') ?? 3;
    difficulty = prefs.getInt('difficulty') ?? 1;
    menuTheme = prefs.getString('menuTheme') ?? 'system';
    ballModel = prefs.getString('ballModel') ?? 'classic';
    hudSize = prefs.getDouble('hudSize') ?? 1.0;
    showPingFps = prefs.getBool('showPingFps') ?? false;
    dataSaver = prefs.getBool('dataSaver') ?? false;
    matches = prefs.getInt('matches') ?? 0;
    dailyCompleted = prefs.getInt('dailyCompleted') ?? 0;
    lastMinuteBest = prefs.getInt('lastMinuteBest') ?? 0;
    lastMinuteFurthest = prefs.getInt('lastMinuteFurthest') ?? 0;
    lastMinuteGoals = prefs.getInt('lastMinuteGoals') ?? 0;
    lastMinuteBestStreak = prefs.getInt('lastMinuteBestStreak') ?? 0;
    xp = prefs.getInt('xp') ?? 0;
    playerName = prefs.getString('player_name') ?? '';
    coins = prefs.getInt('coins') ?? 0;
    trophies = prefs.getInt('trophies') ?? 0;
    friendCode = prefs.getString('friendCode') ?? _generateFriendCode();
    unlockedAvatars = prefs.getStringList('unlockedAvatars') ?? ['default', 'avatar_pro'];
    if (!unlockedAvatars.contains('avatar_pro')) {
      unlockedAvatars.add('avatar_pro');
      prefs.setStringList('unlockedAvatars', unlockedAvatars);
    }
    currentAvatar = prefs.getString('currentAvatar') ?? 'avatar_pro';
    if (currentAvatar == 'default') {
      currentAvatar = 'avatar_pro';
      prefs.setString('currentAvatar', currentAvatar);
    }
    activeTheme = prefs.getString('activeTheme') ?? 'default';
    unlockedThemes = prefs.getStringList('unlockedThemes') ?? ['default'];
    unlockedBoosts = prefs.getStringList('unlockedBoosts') ?? [];
    unlockedBadges = prefs.getStringList('unlockedBadges') ?? [];
    lastDailyRewardTime = prefs.getInt('lastDailyRewardTime') ?? 0;
    if (prefs.getString('friendCode') == null) {
      await prefs.setString('friendCode', friendCode);
    }
    final savedCareer = prefs.getString('lastMinuteCareerStars');
    if (savedCareer != null) {
      final values = (jsonDecode(savedCareer) as List)
          .map((v) => v as int)
          .toList();
      for (
        var i = 0;
        i < min(values.length, lastMinuteCareerStars.length);
        i++
      ) {
        lastMinuteCareerStars[i] = values[i];
      }
    }
    bestDifference = prefs.getDouble('bestDifference') ?? -1;
    final savedWins = prefs.getString('wins');
    if (savedWins != null) {
      wins = (jsonDecode(savedWins) as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value as int),
      );
    }
    offlineProgressDirty =
        prefs.getBool('offlineProgressDirty') ?? progressSnapshot.hasProgress;
    if (!prefs.containsKey('offlineProgressDirty')) {
      await prefs.setBool('offlineProgressDirty', offlineProgressDirty);
    }

    // Try to sync profile if user is logged in
    final client = SupabaseState.client;

    if (client?.auth.currentUser != null) {
      await syncProfile();
    }
  }

  Future<void> syncProfile({bool seedNewProfileFromLocal = true}) async {
    final client = SupabaseState.client;
    final user = client?.auth.currentUser;

    if (client == null || user == null) return;

    try {
      final onlineRes = await client
          .from('online_profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (onlineRes != null) {
        await _applyCloudProfile(onlineRes);

        final serverCode = onlineRes['friend_code'] as String?;
        if (serverCode != null && serverCode.isNotEmpty) {
          friendCode = serverCode;
          await prefs.setString('friendCode', friendCode);
        } else {
          final res = await client
              .from('online_profiles')
              .update({
                'display_name': playerName.isNotEmpty ? playerName : 'Oyuncu',
                'avatar_id': currentAvatar,
              })
              .eq('id', user.id)
              .select('friend_code')
              .single();
          friendCode = res['friend_code'] as String;
          await prefs.setString('friendCode', friendCode);
        }
        
        // Sync local avatar to cloud if cloud has no avatar set
        if (onlineRes['avatar_id'] == null || onlineRes['avatar_id'] == 'default') {
          try {
            await client.from('online_profiles').update({'avatar_id': currentAvatar}).eq('id', user.id);
          } catch (_) {}
        }
      } else {
        final displayName = playerName.isNotEmpty ? playerName : 'Oyuncu';
        final localSeed = seedNewProfileFromLocal
            ? progressSnapshot.toRpcPayload(displayName: displayName)
            : <String, dynamic>{};
        final res = await client
            .from('online_profiles')
            .insert({
              'id': user.id,
              if (!seedNewProfileFromLocal) 'display_name': displayName,
              'rating': seedNewProfileFromLocal ? trophies : 0,
              'matches': seedNewProfileFromLocal ? matches : 0,
              'wins': seedNewProfileFromLocal ? wins.length : 0,
              'avatar_id': currentAvatar,
              ...localSeed,
            })
            .select()
            .single();
        await _applyCloudProfile(res);
        final serverCode = res['friend_code'] as String?;
        if (serverCode != null && serverCode.isNotEmpty) {
          friendCode = serverCode;
          await prefs.setString('friendCode', friendCode);
        }
      }
      await _setOfflineProgressDirty(false);
      checkBadges();
      notifyListeners();
    } catch (e) {
      debugPrint('syncProfile error: $e');
    }
  }

  Future<ProgressMergePreview?> prepareOfflineProgressMerge() async {
    final client = SupabaseState.client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return null;

    final service = ProgressMergeService(client);
    final cloudData = await service.loadCloudProfile(user.id);
    final preview = ProgressMergePreview(
      local: progressSnapshot,
      cloud: ProgressSnapshot.fromCloud(cloudData),
      cloudProfileExists: cloudData != null,
    );

    if (!offlineProgressDirty ||
        !preview.local.hasProgress ||
        !preview.wouldChangeCloud) {
      await syncProfile();
      return null;
    }
    return preview;
  }

  Future<void> mergeOfflineProgress(ProgressMergePreview preview) async {
    final client = SupabaseState.client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      throw StateError('Çevrimiçi oturum bulunamadı.');
    }

    await ProgressMergeService(client).merge(
      local: preview.local,
      displayName: playerName.isNotEmpty ? playerName : 'Oyuncu',
    );
    await syncProfile();
  }

  Future<void> useCloudProgress(ProgressMergePreview preview) async {
    final client = SupabaseState.client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      throw StateError('Çevrimiçi oturum bulunamadı.');
    }

    if (!preview.cloudProfileExists) {
      await ProgressMergeService(client).createEmptyProfile(
        userId: user.id,
        displayName: playerName.isNotEmpty ? playerName : 'Oyuncu',
      );
    }
    await syncProfile(seedNewProfileFromLocal: false);
  }

  Future<void> _applyCloudProfile(Map<String, dynamic> onlineRes) async {
    playerName = onlineRes['display_name'] as String? ?? playerName;
    trophies = onlineRes['rating'] as int? ?? trophies;
    coins = onlineRes['coins'] as int? ?? coins;
    xp = onlineRes['xp'] as int? ?? xp;
    matches = onlineRes['matches'] as int? ?? matches;

    final cloudProgress = ProgressSnapshot.fromCloud(onlineRes);
    if (onlineRes.containsKey('last_minute_best')) {
      lastMinuteBest = cloudProgress.lastMinuteBest;
    }
    if (onlineRes.containsKey('last_minute_furthest')) {
      lastMinuteFurthest = cloudProgress.lastMinuteFurthest;
    }
    if (onlineRes.containsKey('last_minute_goals')) {
      lastMinuteGoals = cloudProgress.lastMinuteGoals;
    }
    if (onlineRes.containsKey('last_minute_best_streak')) {
      lastMinuteBestStreak = cloudProgress.lastMinuteBestStreak;
    }
    if (onlineRes.containsKey('last_minute_career_stars')) {
      lastMinuteCareerStars = List<int>.from(
        cloudProgress.lastMinuteCareerStars,
      );
    }
    if (onlineRes.containsKey('unlocked_avatars')) {
      unlockedAvatars = List<String>.from(cloudProgress.unlockedAvatars);
    }
    if (onlineRes.containsKey('unlocked_themes')) {
      unlockedThemes = List<String>.from(cloudProgress.unlockedThemes);
    }
    if (onlineRes.containsKey('unlocked_badges')) {
      unlockedBadges = List<String>.from(cloudProgress.unlockedBadges);
    }

    if (onlineRes.containsKey('avatar_id')) {
      final cloudAvatarId = onlineRes['avatar_id'] as String?;
      if (cloudAvatarId != null && cloudAvatarId != 'default') {
        currentAvatar = cloudAvatarId;
      }
    }

    if (!unlockedAvatars.contains(currentAvatar)) {
      currentAvatar = 'avatar_pro';
    }
    if (!unlockedThemes.contains(activeTheme)) {
      activeTheme = 'default';
    }

    await Future.wait([
      prefs.setString('player_name', playerName),
      prefs.setInt('trophies', trophies),
      prefs.setInt('coins', coins),
      prefs.setInt('xp', xp),
      prefs.setInt('matches', matches),
      prefs.setInt('lastMinuteBest', lastMinuteBest),
      prefs.setInt('lastMinuteFurthest', lastMinuteFurthest),
      prefs.setInt('lastMinuteGoals', lastMinuteGoals),
      prefs.setInt('lastMinuteBestStreak', lastMinuteBestStreak),
      prefs.setString(
        'lastMinuteCareerStars',
        jsonEncode(lastMinuteCareerStars),
      ),
      prefs.setStringList('unlockedAvatars', unlockedAvatars),
      prefs.setStringList('unlockedThemes', unlockedThemes),
      prefs.setStringList('unlockedBadges', unlockedBadges),
      prefs.setString('currentAvatar', currentAvatar),
      prefs.setString('activeTheme', activeTheme),
    ]);
  }

  Future<void> _setOfflineProgressDirty(bool value) async {
    offlineProgressDirty = value;
    await prefs.setBool('offlineProgressDirty', value);
  }

  void _markOfflineProgressDirty() {
    if (SupabaseState.client?.auth.currentUser != null) return;
    offlineProgressDirty = true;
    prefs.setBool('offlineProgressDirty', true);
  }

  Future<void> _syncUnlockCollections() async {
    final client = SupabaseState.client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return;

    try {
      await client
          .from('online_profiles')
          .update({
            'unlocked_avatars': unlockedAvatars,
            'unlocked_themes': unlockedThemes,
            'unlocked_badges': unlockedBadges,
            'avatar_id': currentAvatar,
          })
          .eq('id', user.id);
    } catch (error) {
      debugPrint('unlock collections Supabase sync error: $error');
    }
  }

  Future<void> setOption(String key, dynamic value) async {
    if (key == 'sound') sound = value as bool;
    if (key == 'vibration') vibration = value as bool;
    if (key == 'animations') animations = value as bool;
    if (key == 'commentator') commentator = value as bool;
    if (key == 'stadiumSounds') stadiumSounds = value as bool;
    if (key == 'goalCelebration') goalCelebration = value as bool;
    if (key == 'matchDuration') matchDuration = value as int;
    if (key == 'difficulty') difficulty = value as int;
    if (key == 'menuTheme') menuTheme = value as String;
    if (key == 'ballModel') ballModel = value as String;
    if (key == 'hudSize') hudSize = value as double;
    if (key == 'showPingFps') showPingFps = value as bool;
    if (key == 'dataSaver') dataSaver = value as bool;

    if (value is bool) await prefs.setBool(key, value);
    if (value is int) await prefs.setInt(key, value);
    if (value is double) await prefs.setDouble(key, value);
    if (value is String) await prefs.setString(key, value);
    notifyListeners();
  }

  Future<void> play(GameSound effect, {bool strong = false}) async {
    if (sound) {
      await audio.stop();
      await audio.play(AssetSource('audio/${effect.name}.wav'));
    }
    if (vibration) {
      strong ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick();
    }
  }

  void tap([GameSound effect = GameSound.tap]) => play(effect);
  void success() => play(GameSound.win, strong: true);
  void perfect() => play(GameSound.perfect, strong: true);
  void warning() => play(GameSound.warning, strong: true);
  void countdown() => play(GameSound.countdown);

  Future<void> addXp(int amount) async {
    xp += amount;
    await prefs.setInt('xp', xp);
    _markOfflineProgressDirty();
    notifyListeners();

    final client = SupabaseState.client;
    final user = client?.auth.currentUser;
    if (client != null && user != null) {
      try {
        await client
            .from('online_profiles')
            .update({'xp': xp})
            .eq('id', user.id);
      } catch (error) {
        debugPrint('addXp Supabase sync error: $error');
      }
    }
  }

  Future<void> recordMatch(String? winner, num difference) async {
    matches++;
    if (winner != null) wins[winner] = (wins[winner] ?? 0) + 1;
    if (bestDifference < 0 || difference < bestDifference) {
      bestDifference = difference.toDouble();
    }
    await prefs.setInt('matches', matches);
    await prefs.setDouble('bestDifference', bestDifference);
    await prefs.setString('wins', jsonEncode(wins));

    // Çarpanlar
    double xpMultiplier = 1.0;
    double coinMultiplier = 1.0;

    if (currentAvatar == 'avatar_pro') xpMultiplier += 0.10;
    if (currentAvatar == 'avatar_captain') coinMultiplier += 0.20;
    if (currentAvatar == 'avatar_legend') {
      xpMultiplier += 0.25;
      coinMultiplier += 0.25;
    }

    if (unlockedBoosts.contains('boost_xp2x')) xpMultiplier += 1.0;
    if (unlockedBoosts.contains('boost_coin2x')) coinMultiplier += 1.0;

    // Maç sonrası coin ve XP ödülü
    int baseCoinReward = difference == 0 ? 100 : 25;
    final coinReward = (baseCoinReward * coinMultiplier).round();
    addCoins(coinReward);

    int baseXpReward = difference == 0 ? 200 : 50;
    await addXp((baseXpReward * xpMultiplier).round());

    // Kupa sistemi (+15 Win, -5 Loss, 0 Tie)
    if (winner == playerName) {
      addTrophies(15);
    } else if (winner != null && winner != playerName) {
      if (!unlockedBoosts.contains('boost_shield')) {
        addTrophies(-5);
      }
    }

    checkBadges();
    notifyListeners();
  }

  Future<void> recordDaily(num difference) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (prefs.getString('lastDaily') != today) {
      dailyCompleted++;
      await prefs.setInt('dailyCompleted', dailyCompleted);
      await prefs.setString('lastDaily', today);
    }
    if (bestDifference < 0 || difference < bestDifference) {
      bestDifference = difference.toDouble();
      await prefs.setDouble('bestDifference', bestDifference);
    }
    await addXp(difference == 0 ? 225 : 75);
    notifyListeners();
  }

  bool get dailyDone =>
      prefs.getString('lastDaily') ==
      DateTime.now().toIso8601String().substring(0, 10);

  Future<void> recordLastMinute(
    int score,
    int stage, {
    bool goal = false,
    int streak = 0,
  }) async {
    if (score > lastMinuteBest) {
      lastMinuteBest = score;
      await prefs.setInt('lastMinuteBest', score);
    }
    if (stage > lastMinuteFurthest) {
      lastMinuteFurthest = stage;
      await prefs.setInt('lastMinuteFurthest', stage);
    }
    if (goal) {
      lastMinuteGoals++;
      await prefs.setInt('lastMinuteGoals', lastMinuteGoals);
      await addXp(100);
    }
    if (streak > lastMinuteBestStreak) {
      lastMinuteBestStreak = streak;
      await prefs.setInt('lastMinuteBestStreak', streak);
    }
    _markOfflineProgressDirty();
    notifyListeners();
  }

  Future<void> recordCareerLevel(int level, int stars) async {
    if (level < 0 ||
        level >= lastMinuteCareerStars.length ||
        stars <= lastMinuteCareerStars[level]) {
      return;
    }
    lastMinuteCareerStars[level] = stars;
    await prefs.setString(
      'lastMinuteCareerStars',
      jsonEncode(lastMinuteCareerStars),
    );
    await addXp(stars * 50);

    try {
      final client = SupabaseState.client;
      final user = client?.auth.currentUser;

      if (client != null && user != null) {
        final currentStage = lastMinuteCareerStars
            .where((stars) => stars > 0)
            .length;

        await client
            .from('online_profiles')
            .update({
              'last_minute_stage': currentStage,
              'last_minute_career_stars': lastMinuteCareerStars,
            })
            .eq('id', user.id);
      }
    } catch (e) {
      debugPrint('Error saving last_minute_stage to Supabase: $e');
    }

    notifyListeners();
  }

  Future<void> savePlayerName(String name) async {
    if (playerName == name) return;
    
    // Yalnızca isim daha önce belirlenmişse (değiştiriliyorsa) para düş.
    // İlk defa isim belirlerken para düşmez.
    if (playerName.isNotEmpty) {
      if (coins >= 500) {
        addCoins(-500);
      } else {
        return; // Yeterli para yoksa isim değiştirme. (UI'da engellenecek)
      }
    }

    playerName = name;
    await prefs.setString('player_name', name);
    notifyListeners();

    final client = SupabaseState.client;
    final user = client?.auth.currentUser;
    if (client != null && user != null) {
      try {
        await client
            .from('online_profiles')
            .update({'display_name': name})
            .eq('id', user.id);
      } catch (e) {
        debugPrint('savePlayerName error: $e');
      }
    }
  }

  int get careerStars =>
      lastMinuteCareerStars.fold(0, (total, value) => total + value);

  String _generateFriendCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  Future<void> setFriendCode(String newCode) async {
    if (newCode.isNotEmpty && newCode != friendCode) {
      friendCode = newCode;
      await prefs.setString('friendCode', friendCode);
      notifyListeners();

      final client = SupabaseState.client;
      final user = client?.auth.currentUser;
      if (client != null && user != null) {
        try {
          await client
              .from('online_profiles')
              .update({'friend_code': newCode})
              .eq('id', user.id);
        } catch (e) {
          debugPrint('setFriendCode Supabase sync error: $e');
        }
      }
    }
  }

  Future<void> setLastDailyRewardTime(int timestamp) async {
    lastDailyRewardTime = timestamp;
    await prefs.setInt('lastDailyRewardTime', timestamp);
    notifyListeners();
  }

  Future<bool> claimDailyRewardCoins() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (lastDailyRewardTime == 0 || now - lastDailyRewardTime >= 86400000) {
      addCoins(500);
      displayCoinsOffset = -500; // temporarily hide the coins for animation
      await setLastDailyRewardTime(now);
      return true;
    }
    return false;
  }

  void addDisplayCoinOffset(int amount) {
    displayCoinsOffset += amount;
    notifyListeners();
  }

  void addCoins(int amount) {
    coins += amount;
    prefs.setInt('coins', coins);
    _markOfflineProgressDirty();
    notifyListeners();
    final client = SupabaseState.client;
    final user = client?.auth.currentUser;
    if (client != null && user != null) {
      client
          .from('online_profiles')
          .update({'coins': coins})
          .eq('id', user.id)
          .then((_) {})
          .catchError((_) {});
    }
  }

  bool deductCoins(int amount) {
    if (coins >= amount) {
      coins -= amount;
      prefs.setInt('coins', coins);
      notifyListeners();
      final client = SupabaseState.client;
      final user = client?.auth.currentUser;
      if (client != null && user != null) {
        client
            .from('online_profiles')
            .update({'coins': coins})
            .eq('id', user.id)
            .then((_) {})
            .catchError((_) {});
      }
      return true;
    }
    return false;
  }

  void addTrophies(int amount) {
    trophies += amount;
    prefs.setInt('trophies', trophies);
    notifyListeners();
  }

  void unlockAvatar(String avatarId) {
    if (!unlockedAvatars.contains(avatarId)) {
      unlockedAvatars.add(avatarId);
      prefs.setStringList('unlockedAvatars', unlockedAvatars);
      _markOfflineProgressDirty();
      _syncUnlockCollections();
      notifyListeners();
    }
  }

  void setCurrentAvatar(String avatarId) {
    if (unlockedAvatars.contains(avatarId)) {
      currentAvatar = avatarId;
      prefs.setString('currentAvatar', currentAvatar);
      _markOfflineProgressDirty();
      _syncUnlockCollections();
      notifyListeners();
    }
  }

  void setActiveTheme(String themeId) {
    if (unlockedThemes.contains(themeId)) {
      activeTheme = themeId;
      prefs.setString('activeTheme', activeTheme);
      notifyListeners();
    }
  }

  void unlockTheme(String themeId) {
    if (!unlockedThemes.contains(themeId)) {
      unlockedThemes.add(themeId);
      prefs.setStringList('unlockedThemes', unlockedThemes);
      _markOfflineProgressDirty();
      _syncUnlockCollections();
      notifyListeners();
    }
  }

  void unlockBoost(String boostId) {
    if (!unlockedBoosts.contains(boostId)) {
      unlockedBoosts.add(boostId);
      prefs.setStringList('unlockedBoosts', unlockedBoosts);
      notifyListeners();
    }
  }

  // ── Günlük Bedava Ödül ──────────────────────────────────────────
  bool get dailyRewardAvailable {
    final last = prefs.getString('lastDailyReward');
    if (last == null) return true;
    return last != DateTime.now().toIso8601String().substring(0, 10);
  }

  Future<void> claimDailyReward() async {
    if (!dailyRewardAvailable) return;
    addCoins(50);
    addTrophies(10);
    await addXp(30);
    await prefs.setString(
      'lastDailyReward',
      DateTime.now().toIso8601String().substring(0, 10),
    );
    notifyListeners();
  }

  // ── Başarım (Badge) Sistemi ─────────────────────────────────────
  static const Map<String, Map<String, dynamic>> allBadges = {
    'first_match': {
      'title': 'İlk Adım',
      'desc': 'İlk maçını oyna',
      'icon': IconData(0xe5ca, fontFamily: 'MaterialIcons'),
    },
    'ten_matches': {
      'title': 'Deneyimli',
      'desc': '10 maç oyna',
      'icon': IconData(0xe1a0, fontFamily: 'MaterialIcons'),
    },
    'twenty_matches': {
      'title': 'Meydan Efsanesi',
      'desc': '20 maç oyna',
      'icon': IconData(0xf06bb, fontFamily: 'MaterialIcons'),
    },
    'perfect_score': {
      'title': 'Tam İsabet',
      'desc': 'Fark 0 ile kazan',
      'icon': IconData(0xf0634, fontFamily: 'MaterialIcons'),
    },
    'five_wins': {
      'title': 'Galip',
      'desc': '5 galibiyet kazan',
      'icon': IconData(0xe6a5, fontFamily: 'MaterialIcons'),
    },
    'daily_warrior': {
      'title': 'Görev Savaşçısı',
      'desc': '3 günlük görev tamamla',
      'icon': IconData(0xe8e5, fontFamily: 'MaterialIcons'),
    },
    'coin_collector': {
      'title': 'Hazine Avcısı',
      'desc': '1000 MP biriktir',
      'icon': IconData(0xe263, fontFamily: 'MaterialIcons'),
    },
    'last_minute_goal': {
      'title': 'Son Dakika Golcüsü',
      'desc': '5 son dakika golü at',
      'icon': IconData(0xf0635, fontFamily: 'MaterialIcons'),
    },
    'social_butterfly': {
      'title': 'Sosyal Kelebek',
      'desc': 'Bir arkadaş ekle',
      'icon': IconData(0xe7ef, fontFamily: 'MaterialIcons'),
    },
    'level_10': {
      'title': 'Çaylak',
      'desc': 'Seviye 10\'a ulaş',
      'icon': IconData(0xe7fc, fontFamily: 'MaterialIcons'),
    },
    'level_50': {
      'title': 'Usta',
      'desc': 'Seviye 50\'ye ulaş',
      'icon': IconData(0xf06bb, fontFamily: 'MaterialIcons'),
    },
    'trophy_500': {
      'title': 'Yükselen Yıldız',
      'desc': '500 Kupa kazan',
      'icon': IconData(0xea73, fontFamily: 'MaterialIcons'),
    },
    'trophy_2000': {
      'title': 'Şampiyon',
      'desc': '2000 Kupa kazan',
      'icon': IconData(0xe231, fontFamily: 'MaterialIcons'),
    },
  };

  void checkBadges() {
    final totalWins = wins.values.fold(0, (a, b) => a + b);
    final checks = <String, bool>{
      'first_match': matches >= 1,
      'ten_matches': matches >= 10,
      'twenty_matches': matches >= 20,
      'perfect_score': bestDifference == 0,
      'five_wins': totalWins >= 5,
      'daily_warrior': dailyCompleted >= 3,
      'coin_collector': coins >= 1000,
      'last_minute_goal': lastMinuteGoals >= 5,
      'level_10': level >= 10,
      'level_50': level >= 50,
      'trophy_500': trophies >= 500,
      'trophy_2000': trophies >= 2000,
    };
    bool changed = false;
    checks.forEach((id, earned) {
      if (earned && !unlockedBadges.contains(id)) {
        unlockedBadges.add(id);
        changed = true;
      }
    });
    if (changed) {
      prefs.setStringList('unlockedBadges', unlockedBadges);
      _markOfflineProgressDirty();
      _syncUnlockCollections();
      notifyListeners();
    }
  }

  void unlockBadge(String badgeId) {
    if (!unlockedBadges.contains(badgeId)) {
      unlockedBadges.add(badgeId);
      prefs.setStringList('unlockedBadges', unlockedBadges);
      _markOfflineProgressDirty();
      _syncUnlockCollections();
      notifyListeners();
    }
  }

  // ── Veri Sıfırlama ─────────────────────────────────────────────
  Future<void> resetAllData() async {
    await prefs.clear();
    sound = true;
    vibration = true;
    animations = true;
    matches = 0;
    dailyCompleted = 0;
    lastMinuteBest = 0;
    lastMinuteFurthest = 0;
    lastMinuteGoals = 0;
    lastMinuteBestStreak = 0;
    bestDifference = -1;
    wins = {};
    lastMinuteCareerStars = List.filled(12, 0);
    playerName = '';
    coins = 350;
    trophies = 1240;
    xp = 0;
    friendCode = _generateFriendCode();
    await prefs.setString('friendCode', friendCode);
    unlockedAvatars = ['default'];
    currentAvatar = 'default';
    activeTheme = 'default';
    unlockedThemes = ['default'];
    unlockedBoosts = [];
    unlockedBadges = [];
    offlineProgressDirty = false;
    await prefs.setBool('offlineProgressDirty', false);
    notifyListeners();
  }
}
