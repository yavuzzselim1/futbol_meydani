import 'package:flutter/material.dart';
import 'package:futbol_meydani/services/game_store.dart';
import 'package:futbol_meydani/services/diagnostic_store.dart';
import 'package:futbol_meydani/services/invite_service.dart';
import 'package:futbol_meydani/online/online_game.dart';
import 'package:futbol_meydani/services/supabase_state.dart';

// ─── Global Instances ────────────────────────────────────────────────
final gameStore = GameStore();
final diagnostics = DiagnosticLogStore(gameStore);
bool get supabaseReady => SupabaseState.ready;

set supabaseReady(bool value) {
  SupabaseState.ready = value;
}

InviteService? inviteService;

/// Global navigator key – davet overlay'ını herhangi bir ekrandan gösterebilmek için
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ─── Online Oturum Yardımcı Fonksiyonları ────────────────────────────
Future<void> saveActiveOnlineSession(
  OnlineSession session,
  String playerName,
) async {
  await gameStore.prefs.setString('online_room_code', session.roomCode);
  await gameStore.prefs.setString('online_player_id', session.playerId);
  await gameStore.prefs.setBool('online_is_host', session.isHost);
  await gameStore.prefs.setString('online_player_name', playerName);
  await gameStore.savePlayerName(playerName);
}

Future<void> clearActiveOnlineSession() async {
  await gameStore.prefs.remove('online_room_code');
  await gameStore.prefs.remove('online_player_id');
  await gameStore.prefs.remove('online_is_host');
  await gameStore.prefs.remove('online_player_name');
}
