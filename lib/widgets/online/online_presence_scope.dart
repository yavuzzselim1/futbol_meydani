import 'dart:async';

import 'package:flutter/material.dart';

import '../../online/online_game.dart';

/// Keeps the server-side presence of an online player fresh while a room is
/// visible. A paused app is marked temporarily disconnected, but the room is
/// not abandoned; returning to the app resumes the same session.
class OnlinePresenceScope extends StatefulWidget {
  const OnlinePresenceScope({
    super.key,
    required this.repository,
    required this.session,
    required this.child,
  });

  final OnlineGameRepository repository;
  final OnlineSession session;
  final Widget child;

  @override
  State<OnlinePresenceScope> createState() => _OnlinePresenceScopeState();
}

class _OnlinePresenceScopeState extends State<OnlinePresenceScope>
    with WidgetsBindingObserver {
  Timer? _heartbeat;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_touch(true));
    _heartbeat = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_touch(true)),
    );
  }

  Future<void> _touch(bool connected) async {
    try {
      await widget.repository.setPresence(widget.session, connected);
    } catch (e) {
      print('PRESENCE ERROR: $e');
      // Realtime stream and the next heartbeat retry the connection.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(_touch(state == AppLifecycleState.resumed));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
