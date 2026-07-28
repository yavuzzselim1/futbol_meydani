import 'dart:convert';
import 'package:futbol_meydani/online/online_game.dart';
import 'package:futbol_meydani/services/game_store.dart';

/// Tanılama log yöneticisi. Hassas verileri (API key, oyuncu adı, kadro) sansürler.
class DiagnosticLogStore {
  DiagnosticLogStore(this._store);

  final GameStore _store;
  static const _historyKey = 'diagnostic_history_v1';
  static const _pendingKey = 'diagnostic_pending_v1';
  static const _maxHistory = 80;
  static const _maxPending = 40;

  List<Map<String, dynamic>> _read(String key) {
    try {
      final raw = _store.prefs.getString(key);
      if (raw == null) return [];
      return (jsonDecode(raw) as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Map<String, dynamic> _safeMetadata(Map<String, dynamic> source) {
    final safe = <String, dynamic>{};
    for (final entry in source.entries) {
      final key = entry.key.toLowerCase();
      if (key.contains('key') ||
          key.contains('token') ||
          key.contains('secret') ||
          key.contains('password') ||
          key.contains('name') ||
          key.contains('player') ||
          key.contains('squad')) {
        continue;
      }
      final value = entry.value;
      if (value is num || value is bool) safe[entry.key] = value;
      if (value is String) {
        safe[entry.key] = value.length > 80 ? value.substring(0, 80) : value;
      }
    }
    return safe;
  }

  Future<void> record({
    required String level,
    required String event,
    String errorCode = '',
    Map<String, dynamic> metadata = const {},
    OnlineGameRepository? repository,
  }) async {
    final entry = <String, dynamic>{
      'at': DateTime.now().toUtc().toIso8601String(),
      'level': level,
      'event': event,
      'code': errorCode,
      'meta': _safeMetadata(metadata),
    };
    final history = _read(_historyKey)..add(entry);
    if (history.length > _maxHistory) {
      history.removeRange(0, history.length - _maxHistory);
    }
    await _store.prefs.setString(_historyKey, jsonEncode(history));
    if (repository == null || repository is LocalOnlineGameRepository) return;
    try {
      await repository.writeDiagnosticLog(
        level: level,
        event: event,
        errorCode: errorCode,
        metadata: Map<String, dynamic>.from(entry['meta'] as Map),
      );
      await flush(repository);
    } catch (_) {
      final pending = _read(_pendingKey)..add(entry);
      if (pending.length > _maxPending) {
        pending.removeRange(0, pending.length - _maxPending);
      }
      await _store.prefs.setString(_pendingKey, jsonEncode(pending));
    }
  }

  Future<void> flush(OnlineGameRepository repository) async {
    final pending = _read(_pendingKey);
    if (pending.isEmpty) return;
    final remaining = <Map<String, dynamic>>[];
    for (final entry in pending) {
      try {
        await repository.writeDiagnosticLog(
          level: entry['level'] as String? ?? 'info',
          event: entry['event'] as String? ?? 'unknown',
          errorCode: entry['code'] as String? ?? '',
          metadata: Map<String, dynamic>.from(
            (entry['meta'] as Map?) ?? const {},
          ),
        );
      } catch (_) {
        remaining.add(entry);
      }
    }
    await _store.prefs.setString(_pendingKey, jsonEncode(remaining));
  }

  /// Versiyon bilgisi GameStore'dan alınır (PackageInfo olmadan).
  String report() {
    final payload = {
      'app': 'Futbol Meydanı',
      'version': _store.appVersion.isEmpty ? '?.?.?+?' : _store.appVersion,
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'pending_count': _read(_pendingKey).length,
      'events': _read(_historyKey),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<void> clear() async {
    await _store.prefs.remove(_historyKey);
    await _store.prefs.remove(_pendingKey);
  }
}
