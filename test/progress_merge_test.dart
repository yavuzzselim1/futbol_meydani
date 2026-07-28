import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_meydani/models/progress_merge.dart';

ProgressSnapshot snapshot({
  int coins = 0,
  int xp = 0,
  int best = 0,
  int furthest = 0,
  int goals = 0,
  int streak = 0,
  List<int> stars = const [],
  List<String> avatars = const ['default'],
  List<String> themes = const ['default'],
  List<String> badges = const [],
}) {
  return ProgressSnapshot(
    coins: coins,
    xp: xp,
    lastMinuteBest: best,
    lastMinuteFurthest: furthest,
    lastMinuteGoals: goals,
    lastMinuteBestStreak: streak,
    lastMinuteCareerStars: List<int>.generate(
      12,
      (index) => index < stars.length ? stars[index] : 0,
    ),
    unlockedAvatars: avatars,
    unlockedThemes: themes,
    unlockedBadges: badges,
  );
}

void main() {
  group('ProgressSnapshot.fromCloud', () {
    test('eksik alanları güvenli varsayılanlarla doldurur', () {
      final value = ProgressSnapshot.fromCloud({
        'xp': 450,
        'last_minute_career_stars': [3, 5, -2],
      });

      expect(value.xp, 450);
      expect(value.coins, 0);
      expect(value.lastMinuteCareerStars, hasLength(12));
      expect(value.lastMinuteCareerStars.take(3), [3, 3, 0]);
      expect(value.unlockedAvatars, ['default']);
      expect(value.unlockedThemes, ['default']);
    });
  });

  group('ProgressSnapshot.contributesTo', () {
    test('yüksek yerel değer bulutu geliştirir', () {
      final local = snapshot(xp: 900, best: 1200);
      final cloud = snapshot(xp: 600, best: 1400);

      expect(local.contributesTo(cloud), isTrue);
    });

    test('yeni açılan ödül bulutu geliştirir', () {
      final local = snapshot(
        avatars: const ['default', 'avatar_pro'],
        badges: const ['first_match'],
      );
      final cloud = snapshot();

      expect(local.contributesTo(cloud), isTrue);
    });

    test('daha düşük veya aynı yerel ilerleme katkı sağlamaz', () {
      final local = snapshot(
        coins: 50,
        xp: 100,
        stars: const [1, 0],
      );
      final cloud = snapshot(
        coins: 100,
        xp: 200,
        stars: const [2, 0],
      );

      expect(local.contributesTo(cloud), isFalse);
    });
  });

  test('RPC yükü rekabetçi çevrimiçi istatistikleri içermez', () {
    final payload = snapshot(
      coins: 300,
      xp: 700,
      stars: const [3, 2, 1],
    ).toRpcPayload(displayName: 'Selim');

    expect(payload['display_name'], 'Selim');
    expect(payload['coins'], 300);
    expect(payload['xp'], 700);
    expect(payload['last_minute_stage'], 3);
    expect(payload.containsKey('rating'), isFalse);
    expect(payload.containsKey('matches'), isFalse);
    expect(payload.containsKey('wins'), isFalse);
    expect(payload.containsKey('losses'), isFalse);
  });
}
