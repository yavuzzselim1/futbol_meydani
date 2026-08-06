import 'dart:async';
import 'package:flutter/material.dart';
import '../models/ranked_league.dart';
import '../online/ranked_league_repository.dart';

class RankedLeagueStore extends ChangeNotifier {
  final RankedLeagueRepository _repository;
  RankedLeagueRepository get repository => _repository;
  
  CompetitiveSeason? activeSeason;
  List<LeagueDefinition> allLeagues = [];
  PlayerLadder? currentLadder;
  ChampionsQualification? championsQualification;
  
  LeagueDefinition? get currentLeague {
    if (currentLadder == null) return null;
    try {
      return allLeagues.firstWhere((l) => l.id == currentLadder!.leagueId);
    } catch (_) {
      return null;
    }
  }

  StreamSubscription? _ladderSubscription;
  bool _initialized = false;
  bool get isInitialized => _initialized;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  RankedLeagueStore(this._repository);

  Future<void> initialize() async {
    if (_initialized) return;
    _isLoading = true;
    notifyListeners();

    try {
      activeSeason = await _repository.getActiveSeason();
      allLeagues = await _repository.getLeagueDefinitions();
      
      if (activeSeason != null) {
        currentLadder = await _repository.getPlayerLadder(activeSeason!.id, 'normal');
        championsQualification = await _repository.getChampionsQualification(activeSeason!.id);
        
        // Setup realtime subscription
        _ladderSubscription?.cancel();
        _ladderSubscription = _repository.watchPlayerLadder(activeSeason!.id, 'normal').listen((ladder) {
          currentLadder = ladder;
          notifyListeners();
        });
      }
    } finally {
      _isLoading = false;
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    _initialized = false;
    await initialize();
  }

  @override
  void dispose() {
    _ladderSubscription?.cancel();
    super.dispose();
  }
}
