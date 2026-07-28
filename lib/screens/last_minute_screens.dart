// For ProfileStat
// For WinnerCelebration

// ─── LastMinutePhase Enum ───────────────────────────────────────────
enum LastMinutePhase { intro, aiming, decision, finished }

// ─── LastMinuteScreen ───────────────────────────────────────────────

enum LastMinuteDifficulty { easy, normal, master }

enum AdvancedMinutePhase { setup, challenge, choice, recovery, finished }

enum MinuteChallenge { pass, dribble, press, throughBall, shot, keeper }

extension LastMinuteDifficultyInfo on LastMinuteDifficulty {
  String get label => switch (this) {
    LastMinuteDifficulty.easy => 'Kolay',
    LastMinuteDifficulty.normal => 'Normal',
    LastMinuteDifficulty.master => 'Usta',
  };
  int get seconds => switch (this) {
    LastMinuteDifficulty.easy => 75,
    LastMinuteDifficulty.normal => 60,
    LastMinuteDifficulty.master => 50,
  };
  int get lives => switch (this) {
    LastMinuteDifficulty.easy => 4,
    LastMinuteDifficulty.normal => 3,
    LastMinuteDifficulty.master => 2,
  };
  double get zone => switch (this) {
    LastMinuteDifficulty.easy => .27,
    LastMinuteDifficulty.normal => .20,
    LastMinuteDifficulty.master => .14,
  };
  int get speed => switch (this) {
    LastMinuteDifficulty.easy => 1450,
    LastMinuteDifficulty.normal => 1120,
    LastMinuteDifficulty.master => 820,
  };
}
