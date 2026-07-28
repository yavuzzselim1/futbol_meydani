import 'dart:async';
import 'package:flutter/material.dart';
import '../../online/online_game.dart';

import '../../constants.dart';
import '../../widgets/common_widgets.dart';

class OnlineProfileScreen extends StatelessWidget {
  const OnlineProfileScreen({super.key, required this.repository});
  final OnlineGameRepository repository;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Online Profilim')),
    body: AppBackground(
      child: SafeArea(
        child: FutureBuilder<List<dynamic>>(
          future: Future.wait<dynamic>([
            repository.loadProfile(),
            repository.loadMatchHistory(),
          ]),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Profil yüklenemedi:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            final profile = snapshot.data![0] as OnlineProfile;
            final history = snapshot.data![1] as List<OnlineMatchRecord>;
            Widget stat(String label, int value) => Expanded(
              child: Column(
                children: [
                  Text(
                    '$value',
                    style: const TextStyle(
                      color: green,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      color: muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            );
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                CardBox(
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 35,
                        backgroundColor: Color(0x2271F39A),
                        child: Icon(
                          Icons.military_tech_rounded,
                          color: green,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        profile.name,
                        style: const TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${profile.rating} MEYDAN PUANI',
                        style: const TextStyle(
                          color: green,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          stat('MAÇ', profile.matches),
                          stat('GALİBİYET', profile.wins),
                          stat('BERABERE', profile.draws),
                          stat('MAĞLUBİYET', profile.losses),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'SON MAÇLAR',
                  style: TextStyle(
                    color: muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                if (history.isEmpty)
                  const CardBox(
                    child: Text(
                      'Henüz tamamlanmış online maçın yok.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted),
                    ),
                  )
                else
                  ...history.map((match) {
                    final won = match.result == 'Galibiyet',
                        draw = match.result == 'Berabere';
                    final color = won
                        ? green
                        : draw
                        ? const Color(0xFFFFD166)
                        : const Color(0xFFFF7777);
                    final date = match.playedAt.toLocal();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: panel,
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(
                            color: color.withValues(alpha: .35),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: color.withValues(alpha: .14),
                              child: Text(
                                match.result.substring(0, 1),
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'vs ${match.opponent}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Hedef ${match.target} • Sen ${match.myTotal} / Rakip ${match.opponentTotal}',
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  match.result,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  '${date.day}.${date.month}.${date.year}',
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 8,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class ProfilePlayerTile extends StatelessWidget {
  const ProfilePlayerTile({
    super.key,
    required this.player,
    required this.label,
    required this.isMe,
  });
  final OnlinePlayer player;
  final String label;
  final bool isMe;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: panel,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: isMe ? green.withValues(alpha: .55) : Colors.white10,
      ),
    ),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: player.ready ? green : panel2,
          child: Icon(
            player.ready ? Icons.check_rounded : Icons.person_rounded,
            color: player.ready ? bg : muted,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: muted,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${player.name}${isMe ? ' • Sen' : ''}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: player.ready
                ? green.withValues(alpha: .12)
                : Colors.white.withValues(alpha: .05),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            player.ready ? 'HAZIR' : 'BEKLİYOR',
            style: TextStyle(
              color: player.ready ? green : muted,
              fontSize: 8,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}
