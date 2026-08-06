import 'package:flutter/material.dart';
import 'package:futbol_meydani/constants.dart';
import 'package:futbol_meydani/online/online_game.dart';
import 'package:futbol_meydani/widgets/common_widgets.dart';
import '../services/supabase_state.dart';

/// Yeni ekran: Liderlik Tablosu — Top 50 oyuncuyu ELO puanına göre listeler.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, required this.repository});
  final OnlineGameRepository repository;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;
  String? _error;
  String? _myId;

  @override
  void initState() {
    super.initState();
    _myId = SupabaseState.client?.auth.currentUser?.id;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.repository.loadLeaderboard();
      if (mounted) {
        setState(() {
          _entries = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liderlik Tablosu'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? ErrorView(
                  message: 'Liderlik tablosu yüklenemedi.',
                  onRetry: _load,
                )
              : _entries.isEmpty
              ? const Center(
                  child: Text(
                    'Henüz oyuncu yok.',
                    style: TextStyle(color: muted),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  itemCount: _entries.length,
                  itemBuilder: (_, i) {
                    final entry = _entries[i];
                    final rank = entry['rank'] as int? ?? (i + 1);
                    final name = entry['display_name'] as String? ?? '—';
                    final rating = entry['rating'] as int? ?? 1000;
                    final wins = entry['wins'] as int? ?? 0;
                    final matches = entry['matches'] as int? ?? 0;
                    final isMe = entry['id'] == _myId;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isMe ? green.withValues(alpha: .08) : panel,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isMe ? green : Colors.white10,
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 36,
                            child: Text(
                              '#$rank',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: rank == 1
                                    ? const Color(0xFFFFD166)
                                    : rank == 2
                                    ? const Color(0xFFCFD8DC)
                                    : rank == 3
                                    ? const Color(0xFFBF8B4A)
                                    : muted,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              name + (isMe ? ' (Sen)' : ''),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: isMe ? green : Colors.white,
                              ),
                            ),
                          ),
                          Text(
                            '$wins G',
                            style: const TextStyle(color: muted, fontSize: 11),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '$matches M',
                            style: const TextStyle(color: muted, fontSize: 11),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '$rating ELO',
                            style: const TextStyle(
                              color: green,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
