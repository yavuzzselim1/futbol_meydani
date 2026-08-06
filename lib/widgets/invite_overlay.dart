import 'dart:async';
import 'package:flutter/material.dart';

import 'package:futbol_meydani/constants.dart';
import 'package:futbol_meydani/globals.dart';
import 'package:futbol_meydani/services/invite_service.dart';
import 'package:futbol_meydani/online/supabase_online_game.dart';
import 'package:futbol_meydani/widgets/online/online_lobby_screen.dart';
import 'package:futbol_meydani/utils/glass_toast.dart';
import '../services/supabase_state.dart';

/// Gelen davet popup'ını gösterir.
/// Davet cevap süresi sayacıyla birlikte çalışır.
/// Kabul/Red/Timeout sonucunu döndürür.
Future<String?> showInviteOverlay(
  BuildContext context, {
  required GameInvite invite,
  required InviteService inviteService,
}) async {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: (ctx, anim, anim2, child) {
      return ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim, child: child),
      );
    },
    pageBuilder: (ctx, anim, anim2) =>
        _InviteOverlayDialog(invite: invite, inviteService: inviteService),
  );
}

class _InviteOverlayDialog extends StatefulWidget {
  const _InviteOverlayDialog({
    required this.invite,
    required this.inviteService,
  });
  final GameInvite invite;
  final InviteService inviteService;

  @override
  State<_InviteOverlayDialog> createState() => _InviteOverlayDialogState();
}

class _InviteOverlayDialogState extends State<_InviteOverlayDialog>
    with SingleTickerProviderStateMixin {
  static const int _timeoutSeconds = InviteService.inviteTimeoutSeconds;
  int _remaining = _timeoutSeconds;
  Timer? _timer;
  late final AnimationController _pulseCtrl;
  bool _responded = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
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

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _onAccept() async {
    if (_responded) return;
    _responded = true;
    _timer?.cancel();
    try {
      await widget.inviteService.acceptInvite(widget.invite.id);
      gameStore.tap(GameSound.start);
    } catch (e) {
      debugPrint('Davet kabul hatası: $e');
    }
    if (mounted) Navigator.of(context).pop('accepted');
  }

  Future<void> _onReject() async {
    if (_responded) return;
    _responded = true;
    _timer?.cancel();
    try {
      await widget.inviteService.rejectInvite(widget.invite.id);
      gameStore.tap(GameSound.warning);
    } catch (e) {
      debugPrint('Davet red hatası: $e');
    }
    if (mounted) Navigator.of(context).pop('rejected');
  }

  Future<void> _onTimeout() async {
    if (_responded) return;
    _responded = true;
    try {
      await widget.inviteService.expireInvite(widget.invite.id);
    } catch (e) {
      debugPrint('Davet expire hatası: $e');
    }
    if (mounted) Navigator.of(context).pop('expired');
  }

  @override
  Widget build(BuildContext context) {
    final progress = _remaining / _timeoutSeconds;
    final fromName = widget.invite.fromName ?? 'Bir oyuncu';

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF0A1A12),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: green.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: green.withValues(alpha: 0.15),
                blurRadius: 40,
                spreadRadius: 5,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 30,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Futbol ikonu
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, child) => Transform.scale(
                  scale: 0.95 + 0.1 * _pulseCtrl.value,
                  child: child,
                ),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: green.withValues(alpha: 0.15),
                    border: Border.all(color: green.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(
                    Icons.sports_soccer_rounded,
                    color: green,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Başlık
              const Text(
                'MEYDANA DAVET',
                style: TextStyle(
                  color: green,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),

              // Mesaj
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(
                      text: fromName,
                      style: const TextStyle(
                        color: Color(0xFFFFD166),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const TextSpan(text: ' seni meydana davet etti!'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Countdown timer
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 4,
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
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Kabul Et butonu
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _responded ? null : _onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: green,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                  ),
                  icon: const Icon(Icons.check_rounded, size: 22),
                  label: const Text(
                    'Kabul Et',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Reddet butonu
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _responded ? null : _onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 22),
                  label: const Text(
                    'Reddet',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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

// ─── InviteListenerWrapper ─────────────────────────────────────────
/// Uygulama genelinde gelen davetleri dinler ve popup gösterir.
/// HomeScreen'i saran bir wrapper olarak kullanılır.
class InviteListenerWrapper extends StatefulWidget {
  const InviteListenerWrapper({super.key, required this.child});
  final Widget child;

  @override
  State<InviteListenerWrapper> createState() => _InviteListenerWrapperState();
}

class _InviteListenerWrapperState extends State<InviteListenerWrapper> {
  StreamSubscription? _inviteSub;
  bool _showingInvite = false;

  @override
  void initState() {
    super.initState();
    _startListening();
    _syncProfile();
  }

  Future<void> _syncProfile() async {
    await gameStore.syncProfile();
  }

  void _startListening() {
    if (inviteService == null) return;

    _inviteSub?.cancel();
    _inviteSub = inviteService!.incomingInvites.listen((invite) async {
      await _handleInvite(invite);
    });

    // Ensure the underlying realtime channel is active
    inviteService!.startListening();
    unawaited(inviteService!.syncPendingInvites());
  }

  Future<void> _handleInvite(GameInvite invite) async {
    if (_showingInvite || !mounted) return;

    final client = SupabaseState.client;
    if (client == null) return;

    _showingInvite = true;

    // Gönderen kişinin adını al
    String fromName = 'Bir oyuncu';
    try {
      final profiles = await client
          .from('online_profiles')
          .select('display_name')
          .eq('id', invite.fromId)
          .limit(1);
      if (profiles.isNotEmpty) {
        fromName = profiles.first['display_name'] as String? ?? 'Bir oyuncu';
      }
    } catch (_) {}

    final namedInvite = GameInvite(
      id: invite.id,
      fromId: invite.fromId,
      toId: invite.toId,
      roomCode: invite.roomCode,
      status: invite.status,
      fromName: fromName,
      expiresAt: invite.expiresAt,
    );

    if (!mounted) {
      _showingInvite = false;
      return;
    }

    // Popup göster
    final result = await showInviteOverlay(
      context,
      invite: namedInvite,
      inviteService: inviteService!,
    );

    _showingInvite = false;

    if (result == 'accepted' && mounted) {
      // Lobiye yönlendir
      try {
        final repository = SupabaseOnlineGameRepository(client);
        final session = await repository.joinRoom(
          invite.roomCode,
          gameStore.playerName.isNotEmpty ? gameStore.playerName : 'Oyuncu',
        );
        await saveActiveOnlineSession(session, gameStore.playerName);

        if (mounted && gameStore.data != null) {
          Navigator.of(context).push(
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
        if (mounted) {
          GlassToast.show(context, 'Lobiye katılırken hata: $e', isError: true);
        }
      }
    } else if (result == 'expired' && mounted) {
      GlassToast.show(context, 'Davetin süresi doldu.', isError: true);
    }
  }

  @override
  void dispose() {
    _inviteSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
