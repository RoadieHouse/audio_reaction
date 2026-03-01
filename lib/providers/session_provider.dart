import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../data/default_sounds.dart';
import '../models/audio_cue.dart';
import '../models/training_session.dart';
import '../models/sequence_block.dart';
import '../services/storage_service.dart';

/// Holds the complete application state for training sessions.
///
/// Responsibilities:
/// 1. Persisted sessions list — the library of saved [TrainingSession]s.
/// 2. Draft session — the [TrainingSession] currently being assembled in
///    [CreateSessionScreen]. The draft is isolated from the saved list until
///    [saveDraft] is called.
///
/// Usage (in main.dart):
/// ```dart
/// ChangeNotifierProvider(
///   create: (_) => SessionProvider(),
///   child: MyApp(),
/// )
/// ```
class SessionProvider extends ChangeNotifier {
  SessionProvider({
    required StorageService storage,
    List<TrainingSession>? initialSessions,
  })  : _storage = storage,
        _sessions = List<TrainingSession>.from(initialSessions ?? []);

  // ── State ──────────────────────────────────────────────────────────────────

  final StorageService _storage;
  final List<TrainingSession> _sessions;
  TrainingSession? _draftSession;
  List<AudioCue> _customSounds = [];

  // ── Public Getters ─────────────────────────────────────────────────────────

  /// Immutable view of the saved sessions list.
  List<TrainingSession> get sessions => List.unmodifiable(_sessions);

  /// The session currently being built in CreateSessionScreen, or null if
  /// no draft is in progress.
  TrainingSession? get draftSession => _draftSession;

  /// Whether a draft is currently active.
  bool get hasDraft => _draftSession != null;

  /// The full list of bundled default sounds from [kDefaultAudioCues].
  List<AudioCue> get availableDefaultSounds => kDefaultAudioCues;

  /// Custom recordings discovered by the most recent [loadCustomSounds] call.
  List<AudioCue> get availableCustomSounds => List.unmodifiable(_customSounds);

  // ── Session CRUD ───────────────────────────────────────────────────────────

  /// Appends [session] to the saved sessions list.
  void addSession(TrainingSession session) {
    _sessions.add(session);
    notifyListeners();
    _persist();
  }

  /// Replaces the session whose [TrainingSession.id] matches [updated.id].
  /// Does nothing if no match is found.
  void updateSession(TrainingSession updated) {
    final index = _sessions.indexWhere((s) => s.id == updated.id);
    if (index == -1) return;
    _sessions[index] = updated;
    notifyListeners();
    _persist();
  }

  /// Removes the session with the given [id] from the saved list.
  void deleteSession(String id) {
    final lengthBefore = _sessions.length;
    _sessions.removeWhere((s) => s.id == id);
    if (_sessions.length != lengthBefore) {
      notifyListeners();
      _persist();
    }
  }

  // ── Draft Lifecycle ────────────────────────────────────────────────────────

  /// Creates a blank draft session and begins the build flow.
  ///
  /// Call this when the user taps the FAB on [DashboardScreen].
  void startNewDraft() {
    _draftSession = TrainingSession(
      id: _generateId(),
      title: '',
      totalDuration: Duration.zero,
      sequence: const [],
    );
    notifyListeners();
  }

  /// Loads an existing session into the draft for editing.
  ///
  /// Call this when the user taps an edit button on a saved session tile.
  void editExistingSession(TrainingSession session) {
    _draftSession = session;
    notifyListeners();
  }

  /// Updates the draft's title without rebuilding the block list.
  void updateDraftTitle(String title) {
    if (_draftSession == null) return;
    _draftSession = _draftSession!.copyWith(title: title);
    notifyListeners();
  }

  /// Appends [block] to the end of the draft's sequence.
  void addBlockToDraft(SequenceBlock block) {
    if (_draftSession == null) return;
    _draftSession = _draftSession!.copyWith(
      sequence: [..._draftSession!.sequence, block],
    );
    notifyListeners();
  }

  /// Removes the block with [blockId] from the draft's sequence.
  void removeBlockFromDraft(String blockId) {
    if (_draftSession == null) return;
    _draftSession = _draftSession!.copyWith(
      sequence: _draftSession!.sequence
          .where((b) => b.id != blockId)
          .toList(),
    );
    notifyListeners();
  }

  /// Moves a block from [oldIndex] to [newIndex] within the draft's sequence.
  ///
  /// Intended for use with [ReorderableListView]. Pass the indices exactly as
  /// received from [ReorderableListView.onReorder]; this method applies the
  /// standard index adjustment automatically.
  void reorderDraftBlocks(int oldIndex, int newIndex) {
    if (_draftSession == null) return;
    final blocks = List<SequenceBlock>.from(_draftSession!.sequence);
    // ReorderableListView passes newIndex as if the item is still in its
    // original position, so we adjust when moving downward.
    if (newIndex > oldIndex) newIndex -= 1;
    final item = blocks.removeAt(oldIndex);
    blocks.insert(newIndex, item);
    _draftSession = _draftSession!.copyWith(sequence: blocks);
    notifyListeners();
  }

  /// Validates the draft, computes its total duration, and saves it to the
  /// sessions list (adding if new, replacing if editing an existing session).
  ///
  /// Returns `true` on success, `false` if the draft is null or has an empty
  /// title (caller should surface a validation error to the user).
  bool saveDraft() {
    if (_draftSession == null) return false;
    if (_draftSession!.title.trim().isEmpty) return false;

    // Stamp the computed duration before saving.
    final toSave = _draftSession!.copyWith(
      title: _draftSession!.title.trim(),
      totalDuration: _draftSession!.computedDuration,
    );

    final existingIndex = _sessions.indexWhere((s) => s.id == toSave.id);
    if (existingIndex != -1) {
      _sessions[existingIndex] = toSave;
    } else {
      _sessions.add(toSave);
    }

    _draftSession = null;
    notifyListeners();
    _persist();
    return true;
  }

  /// Discards the current draft without saving. Safe to call even when no
  /// draft is active.
  void discardDraft() {
    if (_draftSession == null) return;
    _draftSession = null;
    notifyListeners();
  }

  // ── Sound Discovery ────────────────────────────────────────────────────────

  /// Scans `<app-documents>/recordings/` for `.m4a` files saved by
  /// [RecordingService] and rebuilds [availableCustomSounds].
  ///
  /// Call this when the sound picker opens or after a new recording is saved.
  Future<void> loadCustomSounds() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${appDir.path}/recordings');

      if (!recordingsDir.existsSync()) {
        _customSounds = [];
        notifyListeners();
        return;
      }

      final files = recordingsDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.m4a'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      _customSounds = files.map((f) {
        final fileName = f.uri.pathSegments.last; // e.g. "my_cue.m4a"
        final displayName = fileName
            .replaceAll('_', ' ')
            .replaceAll('.m4a', '');
        return AudioCue(
          id: fileName, // filename is a stable, unique ID
          name: displayName,
          filePath: f.path,
          isCustom: true,
        );
      }).toList();

      notifyListeners();
    } catch (e) {
      assert(() {
        // ignore: avoid_print
        print('[SessionProvider] loadCustomSounds() failed: $e');
        return true;
      }());
    }
  }

  // ── Private Helpers ────────────────────────────────────────────────────────

  /// Fire-and-forget persistence. Logs errors in debug builds; never throws.
  void _persist() {
    _storage.saveSessions(List.unmodifiable(_sessions)).catchError((e) {
      assert(() {
        // ignore: avoid_print
        print('[SessionProvider] _persist() failed: $e');
        return true;
      }());
    });
  }

  /// Generates a simple unique ID from the current timestamp (microseconds).
  ///
  /// Sufficient for local, single-device use. Replace with `uuid` package if
  /// multi-device sync is ever needed.
  static String _generateId() =>
      DateTime.now().microsecondsSinceEpoch.toString();
}
