import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:futbol_meydani/services/supabase_state.dart';
import 'package:futbol_meydani/globals.dart';
import 'package:futbol_meydani/online/supabase_online_game.dart';
import 'package:futbol_meydani/widgets/online/online_lobby_screen.dart';
import 'package:futbol_meydani/screens/chat_settings_screen.dart';
import 'package:futbol_meydani/utils/glass_toast.dart';
import 'package:futbol_meydani/widgets/home/home_widgets.dart';
import 'package:futbol_meydani/widgets/common_widgets.dart';

class ChatScreen extends StatefulWidget {
  final String friendId;
  final String friendName;

  const ChatScreen({super.key, required this.friendId, required this.friendName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  SupabaseClient? get _client => SupabaseState.client;
  String? _myId;
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _messages = [];
  RealtimeChannel? _messagesChannel;
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  bool _isDeleteMode = false;
  final Set<String> _selectedMessages = {};
  String? _chatBackground;

  String? get _friendAvatarId {
    try {
      final friend = socialStore.friends.firstWhere((f) => f['id'] == widget.friendId);
      return friend['avatar_id'] as String?;
    } catch (_) {
      return null;
    }
  }

  late final AnimationController _bgAnimController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late final Animation<double> _bgScaleAnimation = Tween<double>(begin: 1.15, end: 1.0).animate(
    CurvedAnimation(parent: _bgAnimController, curve: Curves.easeOutCubic),
  );

  @override
  void initState() {
    super.initState();
    _bgAnimController.forward();
    _myId = _client?.auth.currentUser?.id;
    socialStore.addListener(_onSocialStoreUpdated);
    _messages = List.from(socialStore.chatMessages[widget.friendId] ?? []);
    _isLoading = _messages.isEmpty;
    _loadBackground();
    
    if (_myId != null) {
      socialStore.refreshChatMessages(_client!, _myId!, widget.friendId).then((_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        _markUnreadAsRead();
      });
    } else {
      _isLoading = false;
    }
    _setupRealtime();
  }

  Future<void> _loadBackground() async {
    final bg = gameStore.prefs.getString('chat_bg_${widget.friendId}');
    if (bg != null && mounted) {
      setState(() {
        _chatBackground = bg;
      });
    }
  }

  void _onSocialStoreUpdated() {
    if (mounted) {
      setState(() {
        _messages = List.from(socialStore.chatMessages[widget.friendId] ?? []);
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _setupRealtime() {
    if (_myId == null) return;
    
    _messagesChannel = _client!
        .channel('public:chat_${widget.friendId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: _myId,
          ),
          callback: (payload) {
            if (payload.newRecord['sender_id'] == widget.friendId) {
              _addNewMessage(payload.newRecord);
              _markAsRead(payload.newRecord['id']);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'sender_id',
            value: _myId,
          ),
          callback: (payload) {
            if (mounted) {
              setState(() {
                final idx = _messages.indexWhere((m) => m['id'] == payload.newRecord['id']);
                if (idx != -1) {
                  _messages[idx] = payload.newRecord;
                }
              });
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _bgAnimController.dispose();
    socialStore.removeListener(_onSocialStoreUpdated);
    _messagesChannel?.unsubscribe();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _markUnreadAsRead() {
    if (_myId == null) return;
    final unreadIds = _messages
        .where((m) => m['receiver_id'] == _myId && m['is_read'] == false)
        .map((m) => m['id'] as String)
        .toList();
        
    for (final id in unreadIds) {
      _markAsRead(id);
    }
  }

  void _addNewMessage(Map<String, dynamic> msg) {
    socialStore.addMessageLocally(widget.friendId, msg);
  }

  Future<void> _markAsRead(String messageId) async {
    if (_client == null) return;
    try {
      await _client!.from('messages').update({'is_read': true}).eq('id', messageId);
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _deleteSelectedMessages() async {
    if (_selectedMessages.isEmpty || _client == null) {
      setState(() => _isDeleteMode = false);
      return;
    }
    try {
      await _client!.from('messages').delete().inFilter('id', _selectedMessages.toList());
      setState(() {
        _messages.removeWhere((m) => _selectedMessages.contains(m['id']));
        _selectedMessages.clear();
        _isDeleteMode = false;
      });
      // Locally remove from social store
      socialStore.chatMessages[widget.friendId] = _messages;
    } catch (e) {
      debugPrint('Error deleting messages: $e');
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedMessages.contains(id)) {
        _selectedMessages.remove(id);
        if (_selectedMessages.isEmpty) _isDeleteMode = false;
      } else {
        _selectedMessages.add(id);
      }
    });
  }

  Future<void> _sendGameInvite() async {
    if (_client == null || _myId == null || inviteService == null) return;
    
    GlassToast.show(context, 'Lobi oluşturuluyor...');
    
    try {
      final repo = SupabaseOnlineGameRepository(_client!);
      final playerName = gameStore.playerName;
      
      final session = await repo.createRoom(playerName);
      await saveActiveOnlineSession(session, playerName);
      
      final invite = await inviteService!.sendInvite(
        toId: widget.friendId, 
        roomCode: session.roomCode
      );
      
      if (invite != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OnlineLobbyScreen(
              data: gameStore.data!,
              repository: repo,
              session: session,
              invitedFriendName: widget.friendName,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) GlassToast.show(context, 'Lobi oluşturulamadı: $e', isError: true);
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _myId == null || _client == null) return;
    
    _msgController.clear();
    
    // Optimistic UI update
    final tempMsg = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'sender_id': _myId,
      'receiver_id': widget.friendId,
      'content': text,
      'created_at': DateTime.now().toIso8601String(),
      'is_read': false,
    };
    
    _addNewMessage(tempMsg);
    
    try {
      final result = await _client!.from('messages').insert({
        'sender_id': _myId,
        'receiver_id': widget.friendId,
        'content': text,
      }).select().single();
      
      // Update temp message with real one
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m['id'] == tempMsg['id']);
          if (index != -1) {
            _messages[index] = result;
          }
        });
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      // Could show error and remove temp msg here
    }
  }

  String _formatTime(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: _isDeleteMode 
            ? Text('${_selectedMessages.length} seçildi', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20))
            : Row(
                children: [
                  UserAvatarWidget(
                    avatarId: _friendAvatarId,
                    displayName: widget.friendName,
                    radius: 24,
                  ),
                  const SizedBox(width: 14),
                  Text(widget.friendName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 22)),
                ],
              ),
        iconTheme: const IconThemeData(color: Colors.white),
        leadingWidth: 64,
        leading: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: GestureDetector(
                  onTap: _isDeleteMode 
                      ? () {
                          setState(() {
                            _isDeleteMode = false;
                            _selectedMessages.clear();
                          });
                        }
                      : () => Navigator.pop(context),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Center(
                      child: Icon(
                        _isDeleteMode ? Icons.close : Icons.arrow_back_ios_new,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        actions: [
          if (_isDeleteMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                      onPressed: _deleteSelectedMessages,
                    ),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12.0, top: 8.0, bottom: 8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.sports_esports_rounded, color: Color(0xFF00E676), size: 28),
                          onPressed: _sendGameInvite,
                        ),
                        Container(width: 1, height: 24, color: Colors.white.withValues(alpha: 0.2)),
                        Theme(
                          data: Theme.of(context).copyWith(
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                          ),
                          child: PopupMenuButton<String>(
                            color: const Color(0xFF1A1A1A),
                            icon: const Icon(Icons.more_vert, color: Colors.white, size: 28),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            constraints: const BoxConstraints(),
                            onSelected: (value) async {
                              if (value == 'delete') {
                                setState(() => _isDeleteMode = true);
                              } else if (value == 'settings') {
                                final newBg = await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ChatSettingsScreen(friendId: widget.friendId)),
                                );
                                if (newBg != null) {
                                  setState(() => _chatBackground = newBg);
                                }
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'settings',
                                child: Row(
                                  children: [
                                    Icon(Icons.settings, color: Colors.white70, size: 20),
                                    SizedBox(width: 12),
                                    Text('Sohbet ayarları', style: TextStyle(color: Colors.white)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                    SizedBox(width: 12),
                                    Text('Sil', style: TextStyle(color: Colors.redAccent)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          if (_chatBackground != null)
            Positioned.fill(
              child: ScaleTransition(
                scale: _bgScaleAnimation,
                child: Image.asset(
                  _chatBackground!,
                  fit: BoxFit.cover,
                  color: Colors.black.withValues(alpha: 0.4),
                  colorBlendMode: BlendMode.darken,
                ),
              ),
            ),
          if (_chatBackground != null)
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(color: Colors.transparent),
              ),
            ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMine = msg['sender_id'] == _myId;
                      final isSelected = _selectedMessages.contains(msg['id']);
                      
                      return GestureDetector(
                        onTap: _isDeleteMode ? () => _toggleSelection(msg['id']) : null,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: _isDeleteMode ? const EdgeInsets.all(8) : EdgeInsets.zero,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Align(
                            alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Row(
                              mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (_isDeleteMode) ...[
                                  Icon(
                                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                    color: isSelected ? const Color(0xFF00E676) : Colors.white54,
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                if (!isMine) ...[
                                  UserAvatarWidget(
                                    avatarId: _friendAvatarId,
                                    displayName: widget.friendName,
                                    radius: 14,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                ClipRRect(
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(20),
                                    topRight: const Radius.circular(20),
                                    bottomLeft: isMine ? const Radius.circular(20) : const Radius.circular(4),
                                    bottomRight: isMine ? const Radius.circular(4) : const Radius.circular(20),
                                  ),
                                  child: BackdropFilter(
                                    filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                          gradient: isMine
                                              ? LinearGradient(
                                                  colors: [
                                                    const Color(0xFF00E676).withValues(alpha: 0.08), 
                                                    const Color(0xFF00E676).withValues(alpha: 0.02)
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                )
                                              : null,
                                          color: isMine ? null : Colors.white.withValues(alpha: 0.08),
                                          border: Border.all(
                                            color: isMine ? const Color(0xFF00E676).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                                            width: 1.0,
                                          ),
                                          boxShadow: isMine ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.1),
                                              blurRadius: 10,
                                              spreadRadius: 0,
                                            )
                                          ] : null,
                                        ),
                                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            msg['content'],
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                _formatTime(msg['created_at']),
                                                style: TextStyle(
                                                  color: isMine ? Colors.white70 : Colors.white54,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              if (isMine) ...[
                                                const SizedBox(width: 4),
                                                Icon(
                                                  (msg['is_read'] == true) ? Icons.done_all : Icons.check,
                                                  size: 14,
                                                  color: (msg['is_read'] == true) ? Colors.blue.shade100 : Colors.white70,
                                                ),
                                              ]
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          // Chat Input
          if (!_isDeleteMode)
            Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: 12 + MediaQuery.of(context).padding.bottom,
              ),
              color: Colors.transparent,
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: TextField(
                            controller: _msgController,
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendMessage(),
                            decoration: const InputDecoration(
                              hintText: 'Mesaj yaz...',
                              hintStyle: TextStyle(color: Colors.white38),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: true,
                              fillColor: Colors.transparent,
                              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  ],
),
    );
  }
}
