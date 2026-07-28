import 'dart:math';

import 'package:futbol_meydani/models/game_data.dart';

// ─── MultiLeagueData ────────────────────────────────────────────────
class MultiLeagueData {
  MultiLeagueData({
    required this.season,
    required this.leagues,
    required this.teams,
    required this.players,
    required this.questions,
    required this.draws,
  });

  final String season;
  final Map<String, String> leagues;
  final Map<String, String> teams;
  final Map<String, Player> players;
  final Map<String, MultiQuestion> questions;
  final List<EligibleDraw> draws;

  factory MultiLeagueData.fromJson(Map<String, dynamic> json) {
    final playerList = (json['players'] as List)
        .map((item) => Player.fromJson(item as Map<String, dynamic>))
        .toList();
    final questionList = (json['questions'] as List)
        .map((item) => MultiQuestion.fromJson(item as Map<String, dynamic>))
        .toList();
    final leagueMap = <String, String>{};
    for (final raw in json['leagues'] as List) {
      final item = raw as Map<String, dynamic>;
      leagueMap[item['id'] as String] = item['name'] as String;
    }
    final teamMap = <String, String>{};
    for (final raw in json['teams'] as List) {
      final item = raw as Map<String, dynamic>;
      teamMap[item['id'].toString()] = item['name'] as String;
    }
    return MultiLeagueData(
      season: json['season'] as String,
      leagues: leagueMap,
      teams: teamMap,
      players: {for (final player in playerList) player.id: player},
      questions: {for (final q in questionList) q.id: q},
      draws: (json['eligible_draws'] as List)
          .map((item) => EligibleDraw.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  LeagueDrawRound randomRound({Random? source, String? leagueId}) {
    final random = source ?? Random();
    final availableDraws = leagueId == null
        ? draws
        : draws.where((draw) => draw.leagueId == leagueId).toList();
    final questionIds = availableDraws
        .map((draw) => draw.questionId)
        .toSet()
        .toList();
    final chosenQuestion = questionIds[random.nextInt(questionIds.length)];
    final questionDraws = availableDraws
        .where((draw) => draw.questionId == chosenQuestion)
        .toList();
    final leagueIds = questionDraws
        .map((draw) => draw.leagueId)
        .toSet()
        .toList();
    final chosenLeague = leagueIds[random.nextInt(leagueIds.length)];
    final leagueDraws = questionDraws
        .where((draw) => draw.leagueId == chosenLeague)
        .toList();
    final teamCounts = leagueDraws
        .map((draw) => draw.teamIds.length)
        .toSet()
        .toList();
    final chosenTeamCount = teamCounts[random.nextInt(teamCounts.length)];
    final finalPool = leagueDraws
        .where((draw) => draw.teamIds.length == chosenTeamCount)
        .toList();
    final eligible = finalPool[random.nextInt(finalPool.length)];
    final definition = questions[eligible.questionId]!;
    final candidates = players.values
        .where(
          (player) =>
              player.leagueId == eligible.leagueId &&
              eligible.teamIds.contains(player.teamId),
        )
        .toList();
    final range = eligible.targetMax > eligible.targetMin
        ? eligible.targetMax - eligible.targetMin
        : 0;
    final target = eligible.targets.isNotEmpty
        ? eligible.targets[random.nextInt(eligible.targets.length)]
        : eligible.targetMin + (range == 0 ? 0 : random.nextInt(range + 1));
    return LeagueDrawRound(
      metric: definition.id,
      title: definition.title,
      unit: definition.unit,
      prompt: definition.prompt,
      leagueId: eligible.leagueId,
      leagueName: leagues[eligible.leagueId]!,
      teamIds: eligible.teamIds,
      teamNames: eligible.teamIds.map((id) => teams[id] ?? id).toList(),
      target: target,
      candidates: candidates,
    );
  }
}

// ─── MultiQuestion ──────────────────────────────────────────────────
class MultiQuestion {
  MultiQuestion({
    required this.id,
    required this.title,
    required this.unit,
    required this.prompt,
  });
  final String id, title, unit, prompt;
  factory MultiQuestion.fromJson(Map<String, dynamic> json) => MultiQuestion(
    id: json['id'] as String,
    title: json['title'] as String,
    unit: json['unit'] as String,
    prompt: json['prompt_template'] as String,
  );
}

// ─── EligibleDraw ───────────────────────────────────────────────────
class EligibleDraw {
  EligibleDraw({
    required this.leagueId,
    required this.questionId,
    required this.teamIds,
    required this.targetMin,
    required this.targetMax,
    required this.targets,
  });
  final String leagueId, questionId;
  final List<String> teamIds;
  final List<int> targets;
  final int targetMin, targetMax;
  factory EligibleDraw.fromJson(Map<String, dynamic> json) => EligibleDraw(
    leagueId: json['league_id'] as String,
    questionId: json['question_id'] as String,
    teamIds: (json['team_ids'] as List).map((id) => id.toString()).toList(),
    targetMin: (json['target_min'] as num).round(),
    targetMax: (json['target_max'] as num).round(),
    targets: ((json['targets'] as List?) ?? const <dynamic>[])
        .map((value) => (value as num).round())
        .toList(),
  );
}

// ─── LeagueDrawRound ────────────────────────────────────────────────
class LeagueDrawRound {
  LeagueDrawRound({
    required this.metric,
    required this.title,
    required this.unit,
    required this.prompt,
    required this.leagueId,
    required this.leagueName,
    required this.teamIds,
    required this.teamNames,
    required this.target,
    required this.candidates,
  });
  final String metric, title, unit, prompt, leagueId, leagueName;
  final List<String> teamIds, teamNames;
  final int target;
  final List<Player> candidates;
}
