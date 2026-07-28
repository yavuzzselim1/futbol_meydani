import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Oyun daveti modeli
class GameInvite {
  final String id;
  final String fromId;
  final String toId;
  final String roomCode;
  final String status; // pending, accepted, rejected, expired
  final String? fromName;
  final DateTime? expiresAt;

  const GameInvite({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.roomCode,
    required this.status,
    this.fromName,
    this.expiresAt,
  });

  factory GameInvite.fromMap(Map<String, dynamic> map) => GameInvite(
    id: map['id'].toString(),
    fromId: map['from_id'] as String,
    toId: map['to_id'] as String,
    roomCode: map['room_code'] as String,
    status: map['status'] as String? ?? 'pending',
    fromName: map['from_name'] as String?,
    expiresAt: map['expires_at'] != null
        ? DateTime.parse(map['expires_at'] as String)
        : null,
  );
}

/// Davet sistemini yöneten servis.
/// Supabase Realtime ile gelen davetleri dinler ve kaçırılanları senkronlar.
class InviteService {
  InviteService(this.client);
  final SupabaseClient client;

  static const int inviteTimeoutSeconds = 30;

  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _authSubscription;

  final StreamController<GameInvite> _incomingController =
      StreamController<GameInvite>.broadcast();
  final Set<String> _deliveredInviteIds = <String>{};

  /// Gelen davetleri dinlemek için stream
  Stream<GameInvite> get incomingInvites => _incomingController.stream;

  String? _listeningUserId;

  void startListening() {
    _listenForUser(client.auth.currentUser);

    _authSubscription ??= client.auth.onAuthStateChange.listen((data) {
      _listenForUser(data.session?.user);
    });
  }

  void _listenForUser(User? user) {
    if (user == null) {
      if (_channel != null) {
        client.removeChannel(_channel!);
        _channel = null;
      }
      _listeningUserId = null;
      _deliveredInviteIds.clear();
      return;
    }

    if (_listeningUserId == user.id && _channel != null) {
      unawaited(syncPendingInvites());
      return;
    }

    if (_channel != null) {
      client.removeChannel(_channel!);
      _channel = null;
    }

    _listeningUserId = user.id;
    _deliveredInviteIds.clear();

    _channel = client
        .channel('game_invites_${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'game_invites',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'to_id',
            value: user.id,
          ),
          callback: (payload) {
            final map = payload.newRecord;
            if (map.isNotEmpty) {
              _emitInvite(GameInvite.fromMap(map));
            }
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            unawaited(syncPendingInvites());
          } else if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint('Davet Realtime bağlantı hatası: $error');
          }
        });
  }

  void _emitInvite(GameInvite invite) {
    if (invite.status != 'pending') return;
    if (invite.expiresAt?.isBefore(DateTime.now().toUtc()) ?? false) return;
    if (_deliveredInviteIds.contains(invite.id)) return;

    // Broadcast stream geçmiş olayları saklamaz. Henüz ekran dinlemiyorsa
    // daveti işaretlemeyip sonraki senkronizasyonda tekrar getiriyoruz.
    if (!_incomingController.hasListener) return;

    _deliveredInviteIds.add(invite.id);
    _incomingController.add(invite);
  }

  /// Realtime bağlantısı kurulmadan hemen önce gelen davetleri de yakala.
  Future<void> syncPendingInvites() async {
    final user = client.auth.currentUser;
    if (user == null || _incomingController.isClosed) return;

    try {
      final rows = await client
          .from('game_invites')
          .select()
          .eq('to_id', user.id)
          .eq('status', 'pending')
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .order('created_at');

      for (final row in rows) {
        _emitInvite(GameInvite.fromMap(Map<String, dynamic>.from(row)));
      }
    } catch (error) {
      debugPrint('Bekleyen davetler alınamadı: $error');
    }
  }

  /// Davet gönder ve cevap süresi koy.
  Future<GameInvite?> sendInvite({
    required String toId,
    required String roomCode,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) return null;

    final expiresAt = DateTime.now().toUtc().add(
      const Duration(seconds: inviteTimeoutSeconds),
    );

    // Davet oluştur
    final result = await client
        .from('game_invites')
        .insert({
          'from_id': user.id,
          'to_id': toId,
          'room_code': roomCode,
          'status': 'pending',
          'expires_at': expiresAt.toIso8601String(),
        })
        .select()
        .single();

    return GameInvite.fromMap(result);
  }

  /// Gönderilen daveti realtime dinle (davet eden taraf)
  Stream<String> watchInviteStatus(String inviteId) {
    final controller = StreamController<String>.broadcast();

    final channel = client
        .channel('invite_status_$inviteId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'game_invites',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: inviteId,
          ),
          callback: (payload) {
            final newStatus = payload.newRecord['status'] as String?;
            if (newStatus != null) {
              controller.add(newStatus);
            }
          },
        )
        .subscribe();

    controller.onCancel = () {
      client.removeChannel(channel);
    };

    return controller.stream;
  }

  /// Daveti kabul et
  Future<void> acceptInvite(String inviteId) async {
    await client
        .from('game_invites')
        .update({'status': 'accepted'})
        .eq('id', inviteId);
  }

  /// Daveti reddet
  Future<void> rejectInvite(String inviteId) async {
    await client
        .from('game_invites')
        .update({'status': 'rejected'})
        .eq('id', inviteId);
  }

  /// Daveti süresi doldu olarak işaretle
  Future<void> expireInvite(String inviteId) async {
    try {
      await client
          .from('game_invites')
          .update({'status': 'expired'})
          .eq('id', inviteId)
          .eq('status', 'pending'); // Sadece pending ise expire et
    } catch (e) {
      debugPrint('Davet expire hatası: $e');
    }
  }

  /// Servisi durdur
  void dispose() {
    _authSubscription?.cancel();
    if (_channel != null) {
      client.removeChannel(_channel!);
    }
    _incomingController.close();
  }
}
