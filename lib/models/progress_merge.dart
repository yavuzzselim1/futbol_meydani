enum ProgressMergeDecision { merge, useCloud }

class ProgressSnapshot {
  const ProgressSnapshot({
    required this.coins,
    required this.xp,
    required this.lastMinuteBest,
    required this.lastMinuteFurthest,
    required this.lastMinuteGoals,
    required this.lastMinuteBestStreak,
    required this.lastMinuteCareerStars,
    required this.unlockedAvatars,
    required this.unlockedThemes,
    required this.unlockedBadges,
  });

  final int coins;
  final int xp;
  final int lastMinuteBest;
  final int lastMinuteFurthest;
  final int lastMinuteGoals;
  final int lastMinuteBestStreak;
  final List<int> lastMinuteCareerStars;
  final List<String> unlockedAvatars;
  final List<String> unlockedThemes;
  final List<String> unlockedBadges;

  int get careerStars =>
      lastMinuteCareerStars.fold(0, (total, value) => total + value);

  int get careerStage =>
      lastMinuteCareerStars.where((value) => value > 0).length;

  bool get hasProgress =>
      coins > 0 ||
      xp > 0 ||
      lastMinuteBest > 0 ||
      lastMinuteFurthest > 0 ||
      lastMinuteGoals > 0 ||
      lastMinuteBestStreak > 0 ||
      careerStars > 0 ||
      unlockedAvatars.any((id) => id != 'default') ||
      unlockedThemes.any((id) => id != 'default') ||
      unlockedBadges.isNotEmpty;

  bool contributesTo(ProgressSnapshot cloud) {
    if (coins > cloud.coins ||
        xp > cloud.xp ||
        lastMinuteBest > cloud.lastMinuteBest ||
        lastMinuteFurthest > cloud.lastMinuteFurthest ||
        lastMinuteGoals > cloud.lastMinuteGoals ||
        lastMinuteBestStreak > cloud.lastMinuteBestStreak) {
      return true;
    }

    for (var index = 0; index < lastMinuteCareerStars.length; index++) {
      if (lastMinuteCareerStars[index] > cloud.lastMinuteCareerStars[index]) {
        return true;
      }
    }

    return unlockedAvatars.any((id) => !cloud.unlockedAvatars.contains(id)) ||
        unlockedThemes.any((id) => !cloud.unlockedThemes.contains(id)) ||
        unlockedBadges.any((id) => !cloud.unlockedBadges.contains(id));
  }

  Map<String, dynamic> toRpcPayload({required String displayName}) => {
    'display_name': displayName,
    'coins': coins,
    'xp': xp,
    'last_minute_best': lastMinuteBest,
    'last_minute_furthest': lastMinuteFurthest,
    'last_minute_goals': lastMinuteGoals,
    'last_minute_best_streak': lastMinuteBestStreak,
    'last_minute_stage': careerStage,
    'last_minute_career_stars': lastMinuteCareerStars,
    'unlocked_avatars': unlockedAvatars,
    'unlocked_themes': unlockedThemes,
    'unlocked_badges': unlockedBadges,
  };

  factory ProgressSnapshot.fromCloud(Map<String, dynamic>? data) {
    return ProgressSnapshot(
      coins: _asInt(data?['coins']),
      xp: _asInt(data?['xp']),
      lastMinuteBest: _asInt(data?['last_minute_best']),
      lastMinuteFurthest: _asInt(data?['last_minute_furthest']),
      lastMinuteGoals: _asInt(data?['last_minute_goals']),
      lastMinuteBestStreak: _asInt(data?['last_minute_best_streak']),
      lastMinuteCareerStars: _asCareerStars(data?['last_minute_career_stars']),
      unlockedAvatars: _asStringList(
        data?['unlocked_avatars'],
        fallback: const ['default'],
      ),
      unlockedThemes: _asStringList(
        data?['unlocked_themes'],
        fallback: const ['default'],
      ),
      unlockedBadges: _asStringList(data?['unlocked_badges']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  static List<int> _asCareerStars(dynamic value) {
    final result = List<int>.filled(12, 0);
    if (value is! List) return result;

    for (
      var index = 0;
      index < value.length && index < result.length;
      index++
    ) {
      result[index] = _asInt(value[index]).clamp(0, 3).toInt();
    }
    return result;
  }

  static List<String> _asStringList(
    dynamic value, {
    List<String> fallback = const [],
  }) {
    if (value is! List) return List<String>.from(fallback);
    final result =
        value
            .whereType<String>()
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return result.isEmpty ? List<String>.from(fallback) : result;
  }
}

class ProgressMergePreview {
  const ProgressMergePreview({
    required this.local,
    required this.cloud,
    required this.cloudProfileExists,
  });

  final ProgressSnapshot local;
  final ProgressSnapshot cloud;
  final bool cloudProfileExists;

  bool get wouldChangeCloud => local.contributesTo(cloud);
}
