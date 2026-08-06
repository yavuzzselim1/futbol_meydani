import 'dart:ui';
import 'package:flutter/material.dart';
import '../globals.dart';
import '../constants.dart';
import '../models/ranked_league.dart';
import '../models/game_data.dart';
import '../services/supabase_state.dart';
import 'league_leaderboard_screen.dart';

class LeagueHubScreen extends StatefulWidget {
  final GameData data;
  const LeagueHubScreen({super.key, required this.data});

  @override
  State<LeagueHubScreen> createState() => _LeagueHubScreenState();
}

class _LeagueHubScreenState extends State<LeagueHubScreen> {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (rankedStore != null && !rankedStore!.isInitialized) {
        rankedStore!.initialize();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (rankedStore == null) {
      return const Scaffold(body: Center(child: Text("Ranked Store is null")));
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Meydan Ligleri',
          style: TextStyle(fontFamily: 'Oswald', fontWeight: FontWeight.w600),
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
          
          ListenableBuilder(
            listenable: rankedStore!,
            builder: (context, _) {
              if (rankedStore!.isLoading && !rankedStore!.isInitialized) {
                return const Center(child: CircularProgressIndicator(color: green));
              }

              final season = rankedStore!.activeSeason;
              if (season == null) {
                return _buildEmptyState('Şu anda aktif bir sezon bulunmuyor.');
              }

              final allLeagues = List<LeagueDefinition>.from(rankedStore!.allLeagues);
              allLeagues.sort((a, b) => a.tier.compareTo(b.tier));

              return SafeArea(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: allLeagues.length + 1,
                  separatorBuilder: (_, index) => const SizedBox(height: 24),
                  itemBuilder: (context, index) {
                    if (index == 0) return _buildSeasonInfo(season);
                    
                    final league = allLeagues[index - 1];
                    return _buildLeagueCard(league, season);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        child: Text(
          msg,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildSeasonInfo(CompetitiveSeason season) {
    final daysLeft = season.endsAt.difference(DateTime.now()).inDays;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text(
                'Sezon ${season.id}',
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ],
          ),
          Text(
            daysLeft > 0 ? '$daysLeft gün kaldı' : 'Sezon bitiyor',
            style: TextStyle(
              color: daysLeft > 3 ? Colors.white70 : Colors.redAccent,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLeagueCard(LeagueDefinition league, CompetitiveSeason season) {
    final leagueColor = league.color ?? Colors.grey;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LeagueLeaderboardScreen(season: season, league: league),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
          boxShadow: [
            BoxShadow(color: leagueColor.withValues(alpha: 0.1), blurRadius: 10, spreadRadius: 1),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: leagueColor.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: const Border(bottom: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(league.isChampions ? Icons.military_tech : Icons.shield, color: leagueColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    league.displayName.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Oswald',
                      color: leagueColor,
                      fontSize: 18,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(color: leagueColor.withValues(alpha: 0.3), blurRadius: 8),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 20),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: rankedStore!.repository.getLeaderboard(season.id, league.id, 'normal', limit: 5),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2)),
                    );
                  }
                  
                  final list = snapshot.data ?? [];
                  if (list.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: Text('Henüz sıralamaya giren yok.', style: TextStyle(color: Colors.white54))),
                    );
                  }

                  return Column(
                    children: List.generate(5, (index) {
                      final row = index < list.length ? list[index] : null;
                      if (row == null) return const SizedBox();
                      
                      final name = row['name'] ?? '';
                      final trophies = row['trophies'].toString();
                      final isMe = row['user_id'] == SupabaseState.client?.auth.currentUser?.id;
                      final rank = index + 1;
                      
                      final rankColor = rank == 1 ? const Color(0xFFFFD700) : rank == 2 ? const Color(0xFFC0C0C0) : rank == 3 ? const Color(0xFFCD7F32) : Colors.white54;
                      
                      return Container(
                        height: 36,
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFF00E676).withValues(alpha: 0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              child: Text(
                                '$rank.',
                                textAlign: TextAlign.right,
                                style: TextStyle(fontFamily: 'Oswald', color: rankColor, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                name,
                                style: TextStyle(color: isMe ? const Color(0xFF00E676) : Colors.white, fontSize: 13, fontWeight: isMe ? FontWeight.w800 : FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(trophies, style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Oswald', fontWeight: FontWeight.bold)),
                            const SizedBox(width: 4),
                            const Icon(Icons.emoji_events, color: Colors.amber, size: 14),
                          ],
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
