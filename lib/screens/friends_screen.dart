import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:futbol_meydani/constants.dart';
import 'package:futbol_meydani/globals.dart';
import 'package:futbol_meydani/services/invite_service.dart';
import 'package:futbol_meydani/widgets/online/online_lobby_screen.dart';
import 'package:futbol_meydani/online/online_game.dart';
import 'package:futbol_meydani/online/supabase_online_game.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:futbol_meydani/utils/glass_toast.dart';

import '../services/supabase_state.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});
  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _friendCodeController = TextEditingController();
  SupabaseClient? get _client => SupabaseState.client;

  List<Map<String, dynamic>> _friendsList = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _isLoading = true;
  int _pendingCount = 0;
  RealtimeChannel? _friendRequestsChannel;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _loadPendingRequests();
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    final user = _client?.auth.currentUser;
    if (user == null) return;

    _friendRequestsChannel = _client!
        .channel('public:friends')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friends',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'friend_id',
            value: user.id,
          ),
          callback: (payload) {
            if (mounted) {
              _loadPendingRequests();
              _loadFriends();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friends',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            if (mounted) {
              _loadPendingRequests();
              _loadFriends();
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _friendRequestsChannel?.unsubscribe();
    _friendCodeController.dispose();
    super.dispose();
  }

  /// Sadece kabul edilmiş arkadaşlıkları yükle (çift taraflı)
  Future<void> _loadFriends() async {
    if (!mounted) return;
    if (_client == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);

    try {
      var user = _client!.auth.currentUser;
      if (user == null) {
        final response = await _client!.auth.signInAnonymously();
        user = response.user;
      }
      if (user != null) {
        // user_id = ben ve status = accepted → friend_id'leri al
        final sentAccepted = await _client!
            .from('friends')
            .select('friend_id')
            .eq('user_id', user.id)
            .eq('status', 'accepted');

        // friend_id = ben ve status = accepted → user_id'leri al
        final receivedAccepted = await _client!
            .from('friends')
            .select('user_id')
            .eq('friend_id', user.id)
            .eq('status', 'accepted');

        final friendIds = <String>{};
        for (final row in sentAccepted) {
          friendIds.add(row['friend_id'] as String);
        }
        for (final row in receivedAccepted) {
          friendIds.add(row['user_id'] as String);
        }

        if (friendIds.isNotEmpty) {
          final profiles = await _client!
              .from('online_profiles')
              .select('id, display_name, rating, friend_code')
              .inFilter('id', friendIds.toList());
          if (mounted) {
            setState(() {
              _friendsList = List<Map<String, dynamic>>.from(profiles);
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _friendsList = [];
              _isLoading = false;
            });
          }
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Arkadaşlar yüklenirken hata: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Bekleyen arkadaşlık isteklerini yükle (bana gönderilen)
  Future<void> _loadPendingRequests() async {
    if (_client == null) return;
    try {
      var user = _client!.auth.currentUser;
      if (user == null) {
        final response = await _client!.auth.signInAnonymously();
        user = response.user;
      }
      if (user != null) {
        // Bana gönderilen ve henüz pending olan istekler
        final pending = await _client!
            .from('friends')
            .select('id, user_id')
            .eq('friend_id', user.id)
            .eq('status', 'pending');

        if (pending.isNotEmpty) {
          final senderIds = (pending as List)
              .map((r) => r['user_id'] as String)
              .toList();
          final profiles = await _client!
              .from('online_profiles')
              .select('id, display_name, rating')
              .inFilter('id', senderIds);

          // Profil bilgilerini pending verisiyle birleştir
          final combined = <Map<String, dynamic>>[];
          for (final p in pending) {
            final profile = profiles.firstWhere(
              (pr) => pr['id'] == p['user_id'],
              orElse: () => {
                'id': p['user_id'],
                'display_name': 'Oyuncu',
                'rating': 1000,
              },
            );
            combined.add({
              'request_id': p['id'],
              'user_id': p['user_id'],
              'display_name': profile['display_name'],
              'rating': profile['rating'],
            });
          }

          if (mounted) {
            setState(() {
              _pendingRequests = combined;
              _pendingCount = combined.length;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _pendingRequests = [];
              _pendingCount = 0;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Bekleyen istekler yüklenirken hata: $e');
    }
  }

  /// Arkadaşlık isteği gönder (status: pending)
  Future<void> _addFriend() async {
    final code = _friendCodeController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    if (code == gameStore.friendCode) {
      GlassToast.show(context, 'Kendi kodunu ekleyemezsin!', isError: true);
      return;
    }
    if (_client == null) {
      GlassToast.show(context, 'Sunucu bağlantısı kurulamadı.', isError: true);
      return;
    }

    try {
      final profiles = await _client!
          .from('online_profiles')
          .select('id, display_name')
          .eq('friend_code', code)
          .limit(1);
      if (profiles.isEmpty) {
        if (mounted) {
          GlassToast.show(context, 'Böyle bir arkadaş kodu bulunamadı!', isError: true);
        }
        return;
      }

      final targetUser = profiles.first;
      final targetId = targetUser['id'];
      var user = _client!.auth.currentUser;
      if (user == null) {
        final response = await _client!.auth.signInAnonymously();
        user = response.user;
      }

      if (user != null) {
        // Zaten arkadaş mı veya istek var mı kontrol et (her iki yönde)
        final existingSent = await _client!
            .from('friends')
            .select('id, status')
            .eq('user_id', user.id)
            .eq('friend_id', targetId)
            .limit(1);
        final existingReceived = await _client!
            .from('friends')
            .select('id, status')
            .eq('user_id', targetId)
            .eq('friend_id', user.id)
            .limit(1);

        if (existingSent.isNotEmpty) {
          final status = existingSent.first['status'];
          if (status == 'accepted') {
            if (mounted) {
              GlassToast.show(context, 'Bu oyuncu zaten arkadaş listenizde!', isError: true);
            }
          } else {
            if (mounted) {
              GlassToast.show(context, 'Bu oyuncuya zaten istek gönderilmiş!', isError: true);
            }
          }
          return;
        }
        if (existingReceived.isNotEmpty) {
          final status = existingReceived.first['status'];
          if (status == 'accepted') {
            if (mounted) {
              GlassToast.show(context, 'Bu oyuncu zaten arkadaş listenizde!', isError: true);
            }
          } else if (status == 'pending') {
            // Karşı taraf zaten bize istek göndermiş, otomatik kabul et
            await _client!
                .from('friends')
                .update({'status': 'accepted'})
                .eq('id', existingReceived.first['id']);
            if (mounted) {
              GlassToast.show(
                context,
                '${targetUser['display_name']} zaten sana istek göndermişti. Arkadaş oldunuz! 🎉',
                isError: false,
              );
            }
            gameStore.unlockBadge('social_butterfly');
            _friendCodeController.clear();
            _loadFriends();
            _loadPendingRequests();
          }
          return;
        }

        // Yeni istek gönder (status: pending)
        await _client!.from('friends').insert({
          'user_id': user.id,
          'friend_id': targetId,
          'status': 'pending',
        });

        if (mounted) {
          GlassToast.show(
            context,
            '${targetUser['display_name']} adlı oyuncuya arkadaşlık isteği gönderildi! ⏳',
            isError: false,
          );
        }
        _friendCodeController.clear();
      }
    } catch (e) {
      if (mounted) {
        GlassToast.show(context, 'Hata: $e', isError: true);
      }
    }
  }

  /// Arkadaşlık isteğini kabul et
  Future<void> _acceptRequest(Map<String, dynamic> request) async {
    try {
      // İstek satırını accepted yap
      await _client!
          .from('friends')
          .update({'status': 'accepted'})
          .eq('id', request['request_id']);

      gameStore.unlockBadge('social_butterfly');
      if (mounted) {
        GlassToast.show(context, '${request['display_name']} artık arkadaşın! 🎉', isError: false);
      }
      _loadFriends();
      _loadPendingRequests();
    } catch (e) {
      if (mounted) {
        GlassToast.show(context, 'Hata: $e', isError: true);
      }
    }
  }

  /// Arkadaşlık isteğini reddet
  Future<void> _rejectRequest(Map<String, dynamic> request) async {
    try {
      await _client!.from('friends').delete().eq('id', request['request_id']);
      if (mounted) {
        GlassToast.show(context, '${request['display_name']} isteği reddedildi.', isError: true);
      }
      _loadPendingRequests();
    } catch (e) {
      if (mounted) {
        GlassToast.show(context, 'Hata: $e', isError: true);
      }
    }
  }

  Future<void> _removeFriend(Map<String, dynamic> friend) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1A15),
        title: const Text(
          'Arkadaşı Sil',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          "${friend['display_name']} arkadaş listenden silinecek.",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      var user = _client!.auth.currentUser;
      if (user == null) {
        final response = await _client!.auth.signInAnonymously();
        user = response.user;
      }
      if (user != null) {
        // Her iki yöndeki arkadaşlığı sil
        await _client!
            .from('friends')
            .delete()
            .eq('user_id', user.id)
            .eq('friend_id', friend['id']);
        await _client!
            .from('friends')
            .delete()
            .eq('user_id', friend['id'])
            .eq('friend_id', user.id);
        if (mounted) {
          GlassToast.show(context, '${friend['display_name']} silindi.', isError: true);
          _loadFriends();
        }
      }
    } catch (e) {
      if (mounted) {
        GlassToast.show(context, 'Hata: $e', isError: true);
      }
    }
  }

  /// Meydana davet et – lobiye yönlendir, daveti gönder, realtime dinle
  Future<void> _inviteFriend(Map<String, dynamic> friend) async {
    if (_client == null) return;

    try {
      var user = _client!.auth.currentUser;
      if (user == null) {
        final response = await _client!.auth.signInAnonymously();
        user = response.user;
      }
      if (user == null) return;

      // Oda oluştur
      final repository = SupabaseOnlineGameRepository(_client!);
      final session = await repository.createRoom(
        gameStore.playerName.isNotEmpty ? gameStore.playerName : 'Oyuncu',
      );
      await saveActiveOnlineSession(session, gameStore.playerName);

      // Davet gönder
      final inviteService = InviteService(_client!);
      final invite = await inviteService.sendInvite(
        toId: friend['id'] as String,
        roomCode: session.roomCode,
      );

      if (!mounted || invite == null) return;

      // Davet eden kişiyi lobiye yönlendir
      gameStore.tap(GameSound.start);

      // GameData'yı al
      final data = gameStore.data;
      if (data == null) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _InviteWaitingLobby(
            data: data,
            repository: repository,
            session: session,
            invite: invite,
            inviteService: inviteService,
            friendName: friend['display_name'] as String? ?? 'Arkadaş',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        GlassToast.show(context, 'Davet gönderilemedi: $e', isError: true);
      }
    }
  }

  void _showPendingInvitesSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _PendingRequestsSheet(
        requests: _pendingRequests,
        onAccept: _acceptRequest,
        onReject: _rejectRequest,
        onRefresh: _loadPendingRequests,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Arkadaşlar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Meydanda beraber oynamak için arkadaşlarını ekle.',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 20),

              // Senin Kodun
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Senin Arkadaş Kodun:',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          gameStore.friendCode,
                          style: const TextStyle(
                            color: Color(0xFFFFD166),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: Colors.white),
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: gameStore.friendCode),
                        );
                        GlassToast.show(context, 'Kod kopyalandı!', isError: false);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Arkadaş Ekle
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _friendCodeController,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Arkadaş Kodu Gir',
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: green,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _addFriend,
                    child: const Icon(Icons.person_add_rounded),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Arkadaş Listesi
              Row(
                children: [
                  const Text(
                    'Arkadaş Listen',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_friendsList.length}',
                      style: const TextStyle(
                        color: green,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (!supabaseReady)
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(
                        Icons.cloud_off_rounded,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                    ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      _loadPendingRequests().then(
                        (_) => _showPendingInvitesSheet(),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _pendingCount > 0
                            ? const Color(0xFFFFD166).withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _pendingCount > 0
                              ? const Color(0xFFFFD166).withValues(alpha: 0.4)
                              : Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.mail_rounded,
                            color: _pendingCount > 0
                                ? const Color(0xFFFFD166)
                                : Colors.white54,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Bekleyen${_pendingCount > 0 ? ' ($_pendingCount)' : ''}',
                            style: TextStyle(
                              color: _pendingCount > 0
                                  ? const Color(0xFFFFD166)
                                  : Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Expanded(
                child: !supabaseReady
                ? Center(child: SingleChildScrollView(child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.wifi_off_rounded, size: 64, color: Colors.white.withValues(alpha: 0.1)),
                    const SizedBox(height: 16),
                    const Text('Bağlantı kurulamadı. Online değilsin.', style: TextStyle(color: Colors.white54, fontSize: 16)),
                  ])))
                : _isLoading
                  ? const Center(child: CircularProgressIndicator(color: green))
                  : _friendsList.isEmpty
                    ? Center(child: SingleChildScrollView(child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.people_alt_rounded, size: 64, color: Colors.white.withValues(alpha: 0.1)),
                        const SizedBox(height: 16),
                        const Text('Henüz kimseyi eklemedin.', style: TextStyle(color: Colors.white54, fontSize: 16)),
                        const SizedBox(height: 6),
                        const Text('Arkadaş kodunu paylaş ya da yukarıdan ekle!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white30, fontSize: 13)),
                      ])))
                    : RefreshIndicator(
                        onRefresh: () async {
                          await _loadFriends();
                          await _loadPendingRequests();
                        },
                        color: green,
                        child: ListView.builder(
                          itemCount: _friendsList.length,
                          itemBuilder: (ctx, i) {
                            final friend = _friendsList[i];
                            return Dismissible(
                              key: Key(friend['id'].toString()),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.delete_rounded,
                                  color: Colors.redAccent,
                                ),
                              ),
                              confirmDismiss: (_) async {
                                await _removeFriend(friend);
                                return false;
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: const Color(
                                        0xFF5EC8FF,
                                      ).withValues(alpha: 0.15),
                                      child: const Icon(
                                        Icons.person,
                                        color: Color(0xFF5EC8FF),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            friend['display_name'] ?? 'Oyuncu',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${friend['rating'] ?? 1000} Kupa',
                                            style: const TextStyle(
                                              color: Color(0xFFFFD166),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Davet Butonu
                                    IconButton(
                                      tooltip: 'Meydana Davet Et',
                                      icon: const Icon(
                                        Icons.sports_soccer_rounded,
                                        color: green,
                                      ),
                                      onPressed: () => _inviteFriend(friend),
                                    ),
                                    // Sil Butonu
                                    IconButton(
                                      tooltip: 'Arkadaşı Sil',
                                      icon: Icon(
                                        Icons.person_remove_rounded,
                                        color: Colors.redAccent.withValues(
                                          alpha: 0.6,
                                        ),
                                      ),
                                      onPressed: () => _removeFriend(friend),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bekleyen İstekler Bottom Sheet ──────────────────────────────────

class _PendingRequestsSheet extends StatelessWidget {
  const _PendingRequestsSheet({
    required this.requests,
    required this.onAccept,
    required this.onReject,
    required this.onRefresh,
  });
  final List<Map<String, dynamic>> requests;
  final Future<void> Function(Map<String, dynamic>) onAccept;
  final Future<void> Function(Map<String, dynamic>) onReject;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grabber
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Bekleyen İstekler',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      onRefresh();
                      Navigator.pop(context);
                    },
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (requests.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.mark_email_read_rounded,
                        color: Colors.white.withValues(alpha: 0.1),
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Şu an bekleyen istek yok.',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    ],
                  ),
                )
              else
                ...requests.map(
                  (request) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFFD166).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(
                            0xFFFFD166,
                          ).withValues(alpha: 0.15),
                          child: const Icon(
                            Icons.person_add_rounded,
                            color: Color(0xFFFFD166),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                request['display_name'] ?? 'Oyuncu',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${request['rating'] ?? 1000} Kupa',
                                style: const TextStyle(
                                  color: Color(0xFFFFD166),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Kabul
                        IconButton(
                          tooltip: 'Kabul Et',
                          onPressed: () {
                            onAccept(request);
                            Navigator.pop(context);
                          },
                          icon: const Icon(
                            Icons.check_circle_rounded,
                            color: green,
                            size: 28,
                          ),
                        ),
                        // Reddet
                        IconButton(
                          tooltip: 'Reddet',
                          onPressed: () {
                            onReject(request);
                            Navigator.pop(context);
                          },
                          icon: const Icon(
                            Icons.cancel_rounded,
                            color: Colors.redAccent,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Davet Bekleme Lobisi ──────────────────────────────────────────

class _InviteWaitingLobby extends StatefulWidget {
  const _InviteWaitingLobby({
    required this.data,
    required this.repository,
    required this.session,
    required this.invite,
    required this.inviteService,
    required this.friendName,
  });
  final dynamic data; // GameData
  final OnlineGameRepository repository;
  final OnlineSession session;
  final GameInvite invite;
  final InviteService inviteService;
  final String friendName;

  @override
  State<_InviteWaitingLobby> createState() => _InviteWaitingLobbyState();
}

class _InviteWaitingLobbyState extends State<_InviteWaitingLobby> {
  StreamSubscription? _statusSub;
  Timer? _timeoutTimer;
  int _remaining = InviteService.inviteTimeoutSeconds;
  String _status = 'pending'; // pending, accepted, rejected, expired

  @override
  void initState() {
    super.initState();

    // Davet durumunu realtime dinle
    _statusSub = widget.inviteService
        .watchInviteStatus(widget.invite.id)
        .listen((status) {
          if (!mounted) return;
          if (_status == status) return; // Prevent double trigger
          setState(() => _status = status);

          if (status == 'accepted') {
            _timeoutTimer?.cancel();
            // Arkadaş kabul etti → normal lobi ekranına geç
            GlassToast.show(context, '${widget.friendName} daveti kabul etti! 🎉', isError: false);
            // Lobi ekranına yönlendir
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => OnlineLobbyScreen(
                  data: widget.data,
                  repository: widget.repository,
                  session: widget.session,
                ),
              ),
            );
          } else if (status == 'rejected') {
            _timeoutTimer?.cancel();
            GlassToast.show(context, '${widget.friendName} daveti reddetti. 😔', isError: true);
            Navigator.pop(context);
          } else if (status == 'expired') {
            _timeoutTimer?.cancel();
            GlassToast.show(context, 'Davetin süresi doldu.', isError: true);
            Navigator.pop(context);
          }
        });

    // Davet cevap süresi
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _remaining--);
      if (_remaining <= 0) {
        timer.cancel();
        _onTimeout();
      }
    });
  }

  Future<void> _onTimeout() async {
    if (_status != 'pending') return;
    setState(() => _status = 'expired');
    try {
      await widget.inviteService.expireInvite(widget.invite.id);
      await widget.repository.leaveRoom(widget.session);
      await clearActiveOnlineSession();
    } catch (e) {
      debugPrint('Timeout hatası: $e');
    }
    if (mounted) {
      GlassToast.show(context, 'Davetin süresi doldu. Cevap alınamadı.', isError: true);
      Navigator.pop(context);
    }
  }

  Future<void> _cancelInvite() async {
    if (_status == 'cancelled' || _status == 'expired') return;
    setState(() => _status = 'cancelled');
    _timeoutTimer?.cancel();
    if (mounted) {
      Navigator.pop(
        context,
      ); // Pop immediately to prevent double popping from stream
    }

    try {
      await widget.inviteService.expireInvite(widget.invite.id);
      await widget.repository.leaveRoom(widget.session);
      await clearActiveOnlineSession();
    } catch (e) {
      debugPrint('İptal hatası: $e');
    }
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _timeoutTimer?.cancel();
    widget.inviteService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Davet Bekleniyor'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
          onPressed: _cancelInvite,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animasyonlu futbol ikonu
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeInOut,
                builder: (_, value, child) => Transform.scale(
                  scale: 0.9 + 0.1 * value,
                  child: Opacity(opacity: 0.5 + 0.5 * value, child: child),
                ),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: green.withValues(alpha: 0.12),
                    border: Border.all(
                      color: green.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.sports_soccer_rounded,
                    color: green,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              Text(
                '${widget.friendName} bekleniyor...',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Davet ettiğiniz arkadaşın cevabı bekleniyor.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 32),

              // Countdown
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: CircularProgressIndicator(
                      value: _remaining / InviteService.inviteTimeoutSeconds,
                      strokeWidth: 5,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _remaining <= 3 ? Colors.redAccent : green,
                      ),
                    ),
                  ),
                  Text(
                    '$_remaining',
                    style: TextStyle(
                      color: _remaining <= 3 ? Colors.redAccent : Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Oda kodu
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tag_rounded, color: green, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Oda: ${widget.session.roomCode}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // İptal butonu
              OutlinedButton.icon(
                onPressed: _cancelInvite,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text(
                  'Daveti İptal Et',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
