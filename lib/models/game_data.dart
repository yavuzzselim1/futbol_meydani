import 'package:futbol_meydani/models/multi_league.dart';

// ─── GameData ──────────────────────────────────────────────────────
class GameData {
  GameData({
    required this.competition,
    required this.season,
    required this.players,
    required this.questions,
    required this.answers,
    this.multiLeague,
  });

  final String competition;
  final String season;
  final Map<String, Player> players;
  final List<Question> questions;
  final Map<String, num> answers;
  final MultiLeagueData? multiLeague;

  GameData withMultiLeague(MultiLeagueData value) => GameData(
    competition: competition,
    season: season,
    players: players,
    questions: questions,
    answers: answers,
    multiLeague: value,
  );

  factory GameData.fromJson(Map<String, dynamic> json) {
    final competition = json['competition'] as Map<String, dynamic>;
    final playerList = (json['players'] as List)
        .map((e) => Player.fromJson(e as Map<String, dynamic>))
        .toList();
    final answerMap = <String, num>{};
    for (final item in json['answers'] as List) {
      final a = item as Map<String, dynamic>;
      answerMap['${a['question_id']}:${a['player_id']}'] = a['value'] as num;
    }
    return GameData(
      competition: competition['name'] as String,
      season: competition['season'] as String,
      players: {for (final p in playerList) p.id: p},
      questions: (json['questions'] as List)
          .map((e) => Question.fromJson(e as Map<String, dynamic>))
          .toList(),
      answers: answerMap,
    );
  }
}

// ─── Player ─────────────────────────────────────────────────────────
class Player {
  Player({
    required this.id,
    required this.name,
    required this.aliases,
    required this.team,
    required this.position,
    this.leagueId = '',
    this.teamId = '',
    this.stats = const {},
  });

  final String id, name, team, position, leagueId, teamId;
  final List<String> aliases;
  final Map<String, num> stats;

  factory Player.fromJson(Map<String, dynamic> j) => Player(
    id: j['id'] as String,
    name: j['name'] as String,
    aliases: (j['aliases'] as List).cast<String>(),
    team: j['team'] as String,
    position: j['position'] as String,
    leagueId: j['league_id'] as String? ?? '',
    teamId: j['team_id']?.toString() ?? '',
    stats: ((j['stats'] as Map<String, dynamic>?) ?? const <String, dynamic>{})
        .map((key, value) => MapEntry(key, value as num)),
  );
}

// ─── Question ───────────────────────────────────────────────────────
class Question {
  Question({
    required this.id,
    required this.title,
    required this.prompt,
    required this.unit,
    required this.definition,
    required this.candidates,
    required this.targets,
  });

  final String id, title, prompt, unit, definition;
  final List<String> candidates;
  final List<Target> targets;

  factory Question.fromJson(Map<String, dynamic> j) => Question(
    id: j['id'] as String,
    title: j['title'] as String,
    prompt: j['prompt_template'] as String,
    unit: j['unit'] as String,
    definition: j['metric_definition'] as String,
    candidates: (j['candidate_player_ids'] as List).cast<String>(),
    targets: (j['rounds'] as List)
        .map((e) => Target.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

// ─── Target ─────────────────────────────────────────────────────────
class Target {
  Target({required this.value, required this.difficulty});
  final num value;
  final String difficulty;
  factory Target.fromJson(Map<String, dynamic> j) =>
      Target(value: j['target'] as num, difficulty: j['difficulty'] as String);
}

// ─── Pick ───────────────────────────────────────────────────────────
class Pick {
  Pick(this.player, this.value);
  final Player player;
  final num value;
}

// ─── Formation ──────────────────────────────────────────────────────
class Formation {
  const Formation(this.gk, this.df, this.mf, this.fw, this.label);
  final int gk, df, mf, fw;
  final String label;

  int quota(String position) =>
      {'GK': gk, 'DF': df, 'MF': mf, 'FW': fw}[position] ?? 0;

  static Formation forMetric(String metric) {
    if (metric == 'goals' ||
        metric == 'goal_contributions' ||
        metric == 'shots') {
      return const Formation(1, 2, 2, 2, '1-2-2-2 Hücum');
    }
    if (metric == 'assists') {
      return const Formation(1, 2, 3, 1, '1-2-3-1 Oyun Kurucu');
    }
    if (metric == 'tackles' || metric.contains('cards')) {
      return const Formation(1, 3, 2, 1, '1-3-2-1 Savunma');
    }
    return const Formation(1, 3, 2, 1, '1-3-2-1 Dengeli');
  }
}
