import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class SocialStore extends ChangeNotifier {
  late SharedPreferences _prefs;

  // Caches
  List<Map<String, dynamic>> friends = [];
  List<Map<String, dynamic>> conversations = [];
  Map<String, List<Map<String, dynamic>>> chatMessages = {};

  bool isLoaded = false;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();

    final friendsJson = _prefs.getString('social_friends');
    if (friendsJson != null) {
      friends = List<Map<String, dynamic>>.from(jsonDecode(friendsJson));
    }

    final convosJson = _prefs.getString('social_conversations');
    if (convosJson != null) {
      conversations = List<Map<String, dynamic>>.from(jsonDecode(convosJson));
    }

    final chatsJson = _prefs.getString('social_chats');
    if (chatsJson != null) {
      final Map<String, dynamic> decoded = jsonDecode(chatsJson);
      chatMessages = decoded.map((key, value) => MapEntry(key, List<Map<String, dynamic>>.from(value)));
    }

    isLoaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    await _prefs.setString('social_friends', jsonEncode(friends));
    await _prefs.setString('social_conversations', jsonEncode(conversations));
    await _prefs.setString('social_chats', jsonEncode(chatMessages));
  }

  // --- Network Refresh Methods ---

  Future<void> refreshFriends(SupabaseClient client, String myId) async {
    try {
      final sentAccepted = await client.from('friends').select('friend_id').eq('user_id', myId).eq('status', 'accepted');
      final receivedAccepted = await client.from('friends').select('user_id').eq('friend_id', myId).eq('status', 'accepted');

      final friendIds = <String>{};
      for (final row in sentAccepted) friendIds.add(row['friend_id'] as String);
      for (final row in receivedAccepted) friendIds.add(row['user_id'] as String);

      if (friendIds.isEmpty) {
        friends = [];
        await _save();
        notifyListeners();
        return;
      }

      final profiles = await client.from('online_profiles').select('id, display_name, rating, friend_code, avatar_id').inFilter('id', friendIds.toList());

      friends = profiles.map((p) => {
        'id': p['id'],
        'display_name': p['display_name'] ?? 'Bilinmeyen',
        'rating': p['rating'] ?? 1000,
        'friend_code': p['friend_code'] ?? '',
        'avatar_id': p['avatar_id'] ?? 'default',
      }).toList();

      await _save();
      notifyListeners();
    } catch (e) {
      debugPrint('SocialStore friends error: $e');
    }
  }

  Future<void> refreshConversations(SupabaseClient client, String myId) async {
    try {
      await refreshFriends(client, myId);
      
      if (friends.isEmpty) {
        conversations = [];
        await _save();
        notifyListeners();
        return;
      }

      final friendIds = friends.map((f) => f['id'] as String).toList();
      final Map<String, String> profileNames = { for (var f in friends) f['id'] as String: f['display_name'] as String };

      final messages = await client
          .from('messages')
          .select()
          .or('sender_id.eq.$myId,receiver_id.eq.$myId')
          .order('created_at', ascending: true);

      final Map<String, dynamic> latestMessages = {};
      for (final msg in messages) {
        final sender = msg['sender_id'] as String;
        final receiver = msg['receiver_id'] as String;
        final otherId = sender == myId ? receiver : sender;

        if (friendIds.contains(otherId)) {
          latestMessages[otherId] = msg;
        }
      }

      List<Map<String, dynamic>> convos = [];
      for (final fId in latestMessages.keys) {
        final msg = latestMessages[fId];
        convos.add({
          'friend_id': fId,
          'friend_name': profileNames[fId] ?? 'Bilinmeyen',
          'last_message': msg['content'],
          'created_at': msg['created_at'],
          'is_read': msg['is_read'],
          'is_mine': msg['sender_id'] == myId,
        });
      }

      convos.sort((a, b) {
        final da = DateTime.parse(a['created_at'] as String);
        final db = DateTime.parse(b['created_at'] as String);
        return db.compareTo(da);
      });

      conversations = convos;
      await _save();
      notifyListeners();
    } catch (e) {
      debugPrint('SocialStore convos error: $e');
    }
  }

  Future<void> refreshChatMessages(SupabaseClient client, String myId, String friendId) async {
    try {
      final messages = await client
          .from('messages')
          .select()
          .or('and(sender_id.eq.$myId,receiver_id.eq.$friendId),and(sender_id.eq.$friendId,receiver_id.eq.$myId)')
          .order('created_at', ascending: false)
          .limit(30);

      final reversed = List<Map<String, dynamic>>.from(messages.reversed);
      chatMessages[friendId] = reversed;

      await _save();
      notifyListeners();
    } catch (e) {
      debugPrint('SocialStore chat error: $e');
    }
  }

  void addMessageLocally(String friendId, Map<String, dynamic> message) {
    if (chatMessages.containsKey(friendId)) {
      chatMessages[friendId]!.add(message);
    } else {
      chatMessages[friendId] = [message];
    }
    _save();
    notifyListeners();
  }
}

