import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseState {
  SupabaseState._();

  static bool ready = false;

  static SupabaseClient? get client {
    if (!ready) return null;

    try {
      return Supabase.instance.client;
    } catch (_) {
      ready = false;
      return null;
    }
  }
}
