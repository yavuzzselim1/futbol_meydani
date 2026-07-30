import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:futbol_meydani/services/supabase_state.dart';
import 'package:futbol_meydani/screens/chat_screen.dart';
import 'package:futbol_meydani/globals.dart';
import 'package:futbol_meydani/widgets/common_widgets.dart';

class MessagesListScreen extends StatefulWidget {
  const MessagesListScreen({super.key});

  @override
  State<MessagesListScreen> createState() => _MessagesListScreenState();
}

class _MessagesListScreenState extends State<MessagesListScreen> {
  SupabaseClient? get _client => SupabaseState.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _conversations = [];
  RealtimeChannel? _messagesChannel;
  String? _myId;

  @override
  void initState() {
    super.initState();
    _myId = _client?.auth.currentUser?.id;
    socialStore.addListener(_onSocialStoreUpdated);
    _conversations = socialStore.conversations;
    _isLoading = _conversations.isEmpty;
    
    if (_myId != null) {
      socialStore.refreshConversations(_client!, _myId!).then((_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    } else {
      _isLoading = false;
    }
    _setupRealtime();
  }

  void _onSocialStoreUpdated() {
    if (mounted) {
      setState(() {
        _conversations = socialStore.conversations;
        _isLoading = false;
      });
    }
  }

  void _setupRealtime() {
    _messagesChannel = _client!
        .channel('public:messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            if (_myId != null) socialStore.refreshConversations(_client!, _myId!);
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    socialStore.removeListener(_onSocialStoreUpdated);
    _messagesChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _openChat(String friendId, String friendName) async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ChatScreen(friendId: friendId, friendName: friendName),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
    if (_myId != null && mounted) {
      socialStore.refreshConversations(_client!, _myId!);
    }
  }

  void _showFriendSelector() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _FriendSelectorSheet(
        onSelect: (id, name) {
          Navigator.pop(ctx);
          _openChat(id, name);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Mesajlar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
          : _conversations.isEmpty
              ? const Center(
                  child: Text(
                    'Henüz hiç mesajın yok.\nYeni bir sohbete başlamak için + butonuna tıkla.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  itemCount: _conversations.length,
                  padding: const EdgeInsets.only(bottom: 100),
                  itemBuilder: (context, index) {
                    final convo = _conversations[index];
                    final bool unread = !convo['is_mine'] && !(convo['is_read'] as bool);
                    
                    return ListTile(
                      onTap: () => _openChat(convo['friend_id'], convo['friend_name']),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      leading: UserAvatarWidget(
                        avatarId: socialStore.friends.firstWhere(
                          (f) => f['id'] == convo['friend_id'],
                          orElse: () => <String, dynamic>{},
                        )['avatar_id'] as String?,
                        displayName: convo['friend_name'] ?? '?',
                        radius: 22,
                      ),
                      title: Text(
                        convo['friend_name'],
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: unread ? FontWeight.w900 : FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        convo['last_message'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: unread ? Colors.white : Colors.white54,
                          fontWeight: unread ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: unread
                          ? Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: Color(0xFF00E676),
                                shape: BoxShape.circle,
                              ),
                            )
                          : const SizedBox.shrink(),
                    );
                  },
                ),
      floatingActionButton: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF00E676).withValues(alpha: 0.25),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF00E676).withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: _showFriendSelector,
                splashColor: Colors.white.withValues(alpha: 0.2),
                child: const Center(
                  child: Icon(Icons.add, color: Colors.white, size: 28),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FriendSelectorSheet extends StatefulWidget {
  final void Function(String id, String name) onSelect;
  const _FriendSelectorSheet({required this.onSelect});

  @override
  State<_FriendSelectorSheet> createState() => _FriendSelectorSheetState();
}

class _FriendSelectorSheetState extends State<_FriendSelectorSheet> {
  SupabaseClient? get _client => SupabaseState.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _friends = [];

  @override
  void initState() {
    super.initState();
    _friends = socialStore.friends;
    _isLoading = false;
    
    final myId = _client?.auth.currentUser?.id;
    if (myId != null) {
      socialStore.refreshFriends(_client!, myId).then((_) {
        if (mounted) {
          setState(() {
            _friends = socialStore.friends;
            _isLoading = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.only(left: 24, right: 24, top: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.15), width: 1.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const Text(
                'Arkadaş Seç',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
                    : _friends.isEmpty
                        ? const Center(child: Text('Arkadaşın bulunmuyor.', style: TextStyle(color: Colors.white54)))
                        : ListView.builder(
                            controller: scrollController,
                        itemCount: _friends.length,
                        itemBuilder: (context, index) {
                          final f = _friends[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                onTap: () => widget.onSelect(f['id'], f['display_name'] ?? 'İsimsiz'),
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.person, color: Colors.white70, size: 24),
                                  ),
                                ),
                                title: Text(
                                  f['display_name'] ?? 'İsimsiz',
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  });
  }
}
