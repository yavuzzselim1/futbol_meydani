import 'dart:async';
import 'package:flutter/material.dart';
import 'package:futbol_meydani/globals.dart';
import 'package:futbol_meydani/services/invite_service.dart';
import 'package:futbol_meydani/services/supabase_state.dart';
import 'package:futbol_meydani/services/game_store.dart';
import 'package:futbol_meydani/online/supabase_online_game.dart';
import 'package:futbol_meydani/widgets/online/online_lobby_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:futbol_meydani/utils/glass_toast.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final SupabaseClient? _client = SupabaseState.client;
  bool _isLoading = true;
  List<GameInvite> _invites = [];
  StreamSubscription<GameInvite>? _inviteSub;

  @override
  void initState() {
    super.initState();
    _fetchInvites();

    // Sayfa açıkken gelen yeni davetleri anlık dinle ve listeye ekle
    if (inviteService != null) {
      _inviteSub = inviteService!.incomingInvites.listen((invite) {
        if (mounted) {
          setState(() {
            _invites.insert(0, invite); // En üste ekle
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _inviteSub?.cancel(); // Dinlemeyi durdur
    super.dispose();
  }

  Future<void> _fetchInvites() async {
    if (_client == null || _client!.auth.currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final user = _client!.auth.currentUser!;
      // Süresi geçmemiş ve durumu "pending" olan davetleri çek
      final rows = await _client!
          .from('game_invites')
          .select()
          .eq('to_id', user.id)
          .eq('status', 'pending')
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .order('created_at');

      final List<GameInvite> loadedInvites = [];
      final List<String> fromIds = [];

      for (final row in rows) {
        final invite = GameInvite.fromMap(row);
        loadedInvites.add(invite);
        fromIds.add(invite.fromId);
      }

      // Davet gönderen kişilerin isimlerini çek
      if (fromIds.isNotEmpty) {
        final profiles = await _client!
            .from('online_profiles')
            .select('id, display_name')
            .inFilter('id', fromIds);

        for (var i = 0; i < loadedInvites.length; i++) {
          try {
            final profile = profiles.firstWhere(
              (p) => p['id'] == loadedInvites[i].fromId,
            );
            // GameInvite modelini isimi dahil ederek yeniden oluştur
            final map = (rows[i] as Map<String, dynamic>);
            map['from_name'] = profile['display_name'];
            loadedInvites[i] = GameInvite.fromMap(map);
          } catch (_) {
            // Profil bulunamazsa hatayı yoksay
          }
        }
      }

      if (mounted) {
        setState(() {
          _invites = loadedInvites.reversed.toList(); // En yeni en üstte
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Gelen kutusu yükleme hatası: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _accept(GameInvite invite) async {
    if (inviteService == null || _client == null) return;
    try {
      await inviteService!.acceptInvite(invite.id);

      // Odaya katıl ve session oluştur
      final repository = SupabaseOnlineGameRepository(_client!);
      final session = await repository.joinRoom(
        invite.roomCode,
        gameStore.playerName.isNotEmpty ? gameStore.playerName : 'Oyuncu',
      );
      await saveActiveOnlineSession(session, gameStore.playerName);

      if (mounted && gameStore.data != null) {
        // Lobiye yönlendir
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => OnlineLobbyScreen(
              data: gameStore.data!,
              repository: repository,
              session: session,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted)
        GlassToast.show(context, 'Davet kabul edilemedi: $e', isError: true);
    }
  }

  Future<void> _reject(GameInvite invite) async {
    if (inviteService == null) return;
    try {
      await inviteService!.rejectInvite(invite.id);
      setState(() {
        _invites.removeWhere((i) => i.id == invite.id);
      });
    } catch (e) {
      if (mounted)
        GlassToast.show(context, 'Davet reddedilemedi: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Gelen Kutusu',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.greenAccent),
            )
          : _invites.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.mark_email_unread_rounded,
                    size: 72,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Gelen Kutun Boş',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Oyun davetleri ve duyurular burada görünür.',
                    style: TextStyle(color: Colors.white38, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _invites.length,
              itemBuilder: (context, index) {
                final invite = _invites[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.sports_soccer_rounded,
                            color: Colors.greenAccent,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${invite.fromName ?? 'Biri'} seni maça davet ediyor!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _reject(invite),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: BorderSide(
                                  color: Colors.redAccent.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Reddet',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _accept(invite),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.greenAccent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Katıl',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
