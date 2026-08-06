import 'dart:ui';
import 'package:flutter/material.dart';
import '../globals.dart';
import '../constants.dart';
import '../models/ranked_league.dart';
import '../services/supabase_state.dart';

class LeagueLeaderboardScreen extends StatelessWidget {
  final CompetitiveSeason season;
  final LeagueDefinition league;

  const LeagueLeaderboardScreen({
    super.key,
    required this.season,
    required this.league,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          league.displayName.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Oswald',
            fontWeight: FontWeight.w600,
            color: league.color,
            shadows: [
              Shadow(color: league.color.withValues(alpha: 0.4), blurRadius: 10),
            ],
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              'assets/background_online.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: bg),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.black.withOpacity(0.5)),
            ),
          ),
          SafeArea(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: rankedStore!.repository.getLeaderboard(season.id, league.id, 'normal', limit: 100),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.amber));
                }
                
                final list = snapshot.data ?? [];
                
                if (list.isEmpty) {
                  return const Center(
                    child: Text('Henüz bu ligde kimse sıralamaya girmedi.', style: TextStyle(color: Colors.white54)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  physics: const BouncingScrollPhysics(),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final row = list[index];
                    final name = row['name'] ?? '';
                    final trophies = row['trophies']?.toString() ?? '0';
                    final isMe = row['user_id'] == SupabaseState.client?.auth.currentUser?.id;
                    
                    final isFirst = index == 0;
                    final isSecond = index == 1;
                    final isThird = index == 2;
                    final rankColor = isFirst 
                        ? const Color(0xFFFFD700) 
                        : isSecond 
                            ? const Color(0xFFC0C0C0) 
                            : isThird 
                                ? const Color(0xFFCD7F32) 
                                : Colors.white54;
                                
                    return Container(
                      height: 44,
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isMe ? const Color(0xFF00E676).withValues(alpha: 0.15) : (index % 2 == 0 ? Colors.white.withValues(alpha: 0.03) : Colors.transparent),
                        borderRadius: BorderRadius.circular(8),
                        border: isMe ? Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4)) : null,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 32,
                            child: Text(
                              '${index + 1}.',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontFamily: 'Oswald',
                                color: rankColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                color: isMe ? const Color(0xFF00E676) : Colors.white,
                                fontSize: 15,
                                fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                trophies,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontFamily: 'Oswald',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.emoji_events, color: Colors.amber, size: 18),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
