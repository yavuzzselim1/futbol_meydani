import 'package:flutter/material.dart';
import 'package:futbol_meydani/models/game_data.dart';

// ─── normalize ──────────────────────────────────────────────────────
String normalize(String value) => value
    .toLowerCase()
    .replaceAll('ı', 'i')
    .replaceAll('ş', 's')
    .replaceAll('ğ', 'g')
    .replaceAll('ü', 'u')
    .replaceAll('ö', 'o')
    .replaceAll('ç', 'c')
    .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String initials(String name) =>
    name.split(' ').where((e) => e.isNotEmpty).take(2).map((e) => e[0]).join();

String positionName(String value) =>
    const {
      'GK': 'Kaleci',
      'DF': 'Defans',
      'MF': 'Orta Saha',
      'FW': 'Forvet',
    }[value] ??
    value;

IconData positionIcon(String value) =>
    const {
      'GK': Icons.sports_handball,
      'DF': Icons.shield_outlined,
      'MF': Icons.sync_alt,
      'FW': Icons.sports_soccer,
    }[value] ??
    Icons.person;

String formatTime(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

String joinTurkish(List<String> values) {
  if (values.isEmpty) return '';
  if (values.length == 1) return values.first;
  return '${values.take(values.length - 1).join(', ')} ve ${values.last}';
}

Pick emptyPick([String position = '—']) => Pick(
  Player(
    id: 'empty-$position',
    name: 'Seçilmedi',
    aliases: const <String>[],
    team: '—',
    position: position,
  ),
  0,
);

// ─── Online Match Setup ──────────────────────────────────────────────
Map<String, dynamic> createOnlineMatchSetup(dynamic data) {
  final source = data.multiLeague!;
  final draw = source.randomRound();
  final formation = Formation.forMetric(draw.metric);
  return {
    'metric': draw.metric,
    'title': draw.title,
    'unit': draw.unit,
    'prompt': draw.prompt,
    'league_id': draw.leagueId,
    'league_name': draw.leagueName,
    'team_ids': draw.teamIds,
    'team_names': draw.teamNames,
    'target': draw.target,
    'candidate_ids': draw.candidates.map((player) => player.id).toList(),
    'season': source.season,
    'formation': {
      'gk': formation.gk,
      'df': formation.df,
      'mf': formation.mf,
      'fw': formation.fw,
      'label': formation.label,
    },
  };
}

String onlineSetupKey(Map<String, dynamic>? setup) {
  if (setup == null) return '';
  final teams = ((setup['team_ids'] as List?) ?? const []).join(',');
  final candidates = ((setup['candidate_ids'] as List?) ?? const []).join(',');
  return '${setup['metric']}|${setup['target']}|$teams|$candidates';
}
