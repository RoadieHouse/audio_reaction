import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/training_session.dart';

/// Persists and retrieves the list of [TrainingSession]s using
/// [SharedPreferences] (key-value store backed by NSUserDefaults on iOS and
/// SharedPreferences XML on Android).
///
/// Data is stored as a single JSON-encoded string under [_sessionsKey].
/// This is intentionally a thin I/O layer — all business logic lives in the
/// Provider layer above it.
class StorageService {
  static const String _sessionsKey = 'saved_sessions';

  SharedPreferences? _prefs;

  /// Returns the cached [SharedPreferences] instance, fetching it once on
  /// first access. Subsequent calls return the already-resolved instance
  /// without a platform-channel round-trip.
  Future<SharedPreferences> get _sharedPrefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ── Write ───────────────────────────────────────────────────────────────────

  /// Serialises [sessions] to JSON and writes it to persistent storage.
  ///
  /// Overwrites any previously saved data for [_sessionsKey].
  /// Throws on unexpected I/O errors so the Provider layer can surface them.
  Future<void> saveSessions(List<TrainingSession> sessions) async {
    try {
      final prefs = await _sharedPrefs;
      final jsonList = sessions.map((s) => s.toJson()).toList();
      final encoded = jsonEncode(jsonList);
      await prefs.setString(_sessionsKey, encoded);
    } catch (e) {
      _log('saveSessions() failed: $e');
      rethrow;
    }
  }

  // ── Read ────────────────────────────────────────────────────────────────────

  /// Loads and deserialises the saved sessions list.
  ///
  /// Returns an empty list when no data has been saved yet (first launch) or
  /// when the stored data cannot be decoded (corrupt/stale data).
  Future<List<TrainingSession>> loadSessions() async {
    try {
      final prefs = await _sharedPrefs;
      final encoded = prefs.getString(_sessionsKey);

      if (encoded == null || encoded.isEmpty) return [];

      final decoded = jsonDecode(encoded) as List<dynamic>;
      return decoded
          .map((e) => TrainingSession.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Treat any decode error as "no sessions" rather than crashing.
      // Corrupt data will be overwritten on the next successful save.
      _log('loadSessions() failed — returning empty list: $e');
      return [];
    }
  }

  // ── Private Helpers ─────────────────────────────────────────────────────────

  void _log(String message) {
    assert(() {
      // ignore: avoid_print
      print('[StorageService] $message');
      return true;
    }());
  }
}
