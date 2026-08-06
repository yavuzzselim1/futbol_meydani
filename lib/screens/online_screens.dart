import 'package:futbol_meydani/models/game_data.dart';
import '../services/supabase_state.dart';

// ─── supabaseReady ──────────────────────────────────────────────────
bool get supabaseReady => SupabaseState.client != null;

// ─── Online Session Helpers ─────────────────────────────────────────
Map<String, dynamic> createOnlineMatchSetup(GameData data) {
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

// ─── OnlineEntryScreen ──────────────────────────────────────────────

// ─── OnlineMatchmakingScreen ────────────────────────────────────────

// ─── OnlineProfileScreen ────────────────────────────────────────────

// ─── OnlinePlayerTile (main.dart version) ───────────────────────────

// ─── OnlineLobbyScreen ──────────────────────────────────────────────

// ─── OnlineSquadScreen ──────────────────────────────────────────────
