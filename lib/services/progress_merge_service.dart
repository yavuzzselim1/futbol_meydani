import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/progress_merge.dart';

class ProgressMergeService {
  const ProgressMergeService(this.client);

  final SupabaseClient client;

  Future<Map<String, dynamic>?> loadCloudProfile(String userId) async {
    return client
        .from('online_profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
  }

  Future<void> merge({
    required ProgressSnapshot local,
    required String displayName,
  }) async {
    await client.rpc(
      'merge_offline_progress',
      params: {'p_progress': local.toRpcPayload(displayName: displayName)},
    );
  }

  Future<void> createEmptyProfile({
    required String userId,
    required String displayName,
  }) async {
    await client.from('online_profiles').insert({
      'id': userId,
      'display_name': displayName,
    });
  }
}
