import 'dart:async';
import 'dart:math';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/audio_cue.dart';
import '../models/sequence_block.dart';
import '../models/training_session.dart';

// ── Background isolate helper ─────────────────────────────────────────────────

/// Builds a flat list of plain source descriptors from a serialised session.
/// Runs in a background isolate via [compute] so the main thread is never
/// blocked by the playlist-construction loop.
///
/// Structure:
///   1. Warm-up sources  — played exactly once, before the loop.
///   2. Loop sources     — repeated [repeatCount] times (or 999 for infinite).
///
/// Returns a list of Maps with keys:
///   'type'       → 'silence' | 'asset' | 'file'
///   'durationMs' → int (silence only)
///   'path'       → String (asset / file only)
///   'blockIndex' → int? (index into session.sequence; null for 300 ms gaps)
List<Map<String, dynamic>> _buildSourceDescriptors(
    Map<String, dynamic> sessionJson) {
  final session = TrainingSession.fromJson(sessionJson);
  final rng = Random();
  final descriptors = <Map<String, dynamic>>[];

  // Build a lookup: block.id → index in session.sequence
  final blockIndexById = <String, int>{};
  for (var i = 0; i < session.sequence.length; i++) {
    blockIndexById[session.sequence[i].id] = i;
  }

  // Split the sequence: leading WarmUpBlocks play once, everything else loops.
  final warmUpBlocks =
      session.sequence.whereType<WarmUpBlock>().toList();
  final loopBlocks = session.sequence
      .where((b) => b is! WarmUpBlock)
      .toList();

  // ── Step 1: Warm-up (once, not repeated) ─────────────────────────────────
  for (final block in warmUpBlocks) {
    descriptors.add({
      'type': 'silence',
      'durationMs': block.duration.inMilliseconds,
      'blockIndex': blockIndexById[block.id],
    });
  }

  // ── Step 2: Loop passes ───────────────────────────────────────────────────
  // For "infinite" sessions we unroll 999 passes rather than using
  // LoopMode.all, because LoopMode.all would also loop the warm-up.
  final passes = session.isInfinite ? 999 : session.repeatCount;

  for (var pass = 0; pass < passes; pass++) {
    for (var i = 0; i < loopBlocks.length; i++) {
      final block = loopBlocks[i];
      final isLastBlock = (pass == passes - 1) && (i == loopBlocks.length - 1);

      if (block is DelayBlock) {
        descriptors.add({
          'type': 'silence',
          'durationMs': block.duration.inMilliseconds,
          'blockIndex': blockIndexById[block.id],
        });
      } else if (block is ActionBlock) {
        final cue = block.pickCue(rng);
        final path = cue.filePath;
        if (path != null && path.isNotEmpty) {
          descriptors.add({
            'type': cue.isCustom ? 'file' : 'asset',
            'path': path,
            'blockIndex': blockIndexById[block.id],
          });
          // 300 ms gap prevents back-to-back cues sounding like one sound.
          if (!isLastBlock) {
            descriptors.add({
              'type': 'silence',
              'durationMs': 300,
              'blockIndex': null, // inter-cue gap, not a named block
            });
          }
        }
      }
    }
  }

  return descriptors;
}

/// Owns the [AudioPlayer] and manages the full lifecycle of a training
/// session's audio: OS session configuration, playlist compilation, and
/// playback control.
///
/// [CORE-01] All inter-cue timing is handled by just_audio natively via
/// [SilenceAudioSource]. No Dart [Timer] or [Future.delayed] are used, so
/// playback survives screen lock and backgrounding on both iOS and Android.
///
/// [CORE-02] The OS audio session is configured to mix with (and briefly duck)
/// background music (Spotify, Apple Music) without ever stopping it.
class AudioService {
  final AudioPlayer _player = AudioPlayer();
  final AudioPlayer _previewPlayer = AudioPlayer();

  /// Maps each playlist source index to the corresponding index in the
  /// session's [TrainingSession.sequence]. Null entries are 300 ms inter-cue
  /// gap silences that don't correspond to a named block.
  ///
  /// Populated by [loadSession]; empty until then.
  List<int?> _blockIndexMap = const [];

  /// True for playlist items that are real audio files (asset / file).
  /// False for silence sources (warmup, delays, inter-cue gaps).
  /// Used to activate/deactivate the OS audio session dynamically so
  /// background music (Spotify) only ducks while a cue is actually playing.
  List<bool> _isAudioItem = const [];

  /// Retained reference to the OS audio session for dynamic focus management.
  AudioSession? _audioSession;

  /// Subscription to player index changes; drives setActive(true/false).
  StreamSubscription<int?>? _indexSub;

  /// Subscription to preview player state; releases audio focus on completion.
  StreamSubscription<PlayerState>? _previewStateSub;

  // ── Public Streams ──────────────────────────────────────────────────────────

  /// Real-time playback position within the current playlist item.
  Stream<Duration> get positionStream => _player.positionStream;

  /// Duration of the currently playing playlist item (null while loading).
  /// Combine with [positionStream] to compute time-remaining: `duration - position`.
  Stream<Duration?> get currentDurationStream => _player.durationStream;

  /// Index of the currently playing item in the compiled playlist.
  /// Cross-reference with [blockIndexMap] to know which [SequenceBlock] is active.
  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  /// Whether the player is currently playing (not paused, not stopped).
  Stream<bool> get playingStream => _player.playingStream;

  /// Full player state including ProcessingState (idle, loading, buffering,
  /// ready, completed). Use to detect when a finite session ends.
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  /// Maps each playlist source index → index into [TrainingSession.sequence].
  /// Null means the source is an inter-cue gap with no associated block.
  /// Always call after [loadSession] has completed.
  List<int?> get blockIndexMap => List.unmodifiable(_blockIndexMap);

  // ── Initialisation ──────────────────────────────────────────────────────────

  /// Configures the OS audio session so cues mix with background music.
  ///
  /// Call once at app start (e.g., inside [main] or when this service is
  /// first provided) before any call to [loadSession] or [play].
  Future<void> init() async {
    try {
      final session = await AudioSession.instance;
      _audioSession = session;
      await session.configure(
        AudioSessionConfiguration(
          // ── iOS ────────────────────────────────────────────────────────────
          // AVAudioSessionCategoryPlayback + mixWithOthers lets our cues play
          // alongside Spotify / Apple Music AND plays even when the device is
          // on silent/mute mode (unlike 'ambient' which is silenced by the
          // mute switch — critical for outdoor sprint training).
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.mixWithOthers,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,

          // ── Android ────────────────────────────────────────────────────────
          // USAGE_MEDIA routes through the media/music volume stream (the one
          // the user controls with hardware buttons).
          // gainTransientMayDuck: Android will duck (lower the volume of)
          // background music (Spotify, etc.) only while we play — it will NOT
          // pause or stop it. androidWillPauseWhenDucked: false ensures we
          // keep playing if another app requests a duck on us.
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.sonification,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType:
              AndroidAudioFocusGainType.gainTransientMayDuck,
          androidWillPauseWhenDucked: false,
        ),
      );
    } catch (e) {
      // Audio session config is best-effort; the app can still run without it.
      // Log in debug builds; surface to the user only if playback fails later.
      assert(() {
        // ignore: avoid_print
        print('[AudioService] init() failed: $e');
        return true;
      }());
    }
  }

  // ── Session Compiler ────────────────────────────────────────────────────────

  /// Compiles [session] into a just_audio playlist and loads it, ready for
  /// an immediate [play] call.
  ///
  /// The heavy descriptor-building work runs in a background isolate via
  /// [compute] to avoid blocking the main thread ([CORE-01]).
  /// Descriptors are converted to [AudioSource] objects on the main isolate
  /// after [compute] returns, then loaded with [preload: true] so buffering
  /// completes before [play] is called.
  Future<void> loadSession(TrainingSession session) async {
    // Ensure the player is idle before loading new sources to avoid
    // ExoPlayer's internal operation queue deadlocking on setAudioSources.
    await _player.stop();

    final descriptors =
        await compute(_buildSourceDescriptors, session.toJson());

    final sources = <AudioSource>[];
    final indexMap = <int?>[];
    final audioMap = <bool>[];
    for (final d in descriptors) {
      final type = d['type'] as String;
      if (type == 'silence') {
        sources.add(SilenceAudioSource(
          duration: Duration(milliseconds: d['durationMs'] as int),
        ));
        audioMap.add(false);
      } else if (type == 'asset') {
        sources.add(AudioSource.asset(d['path'] as String));
        audioMap.add(true);
      } else if (type == 'file') {
        sources.add(AudioSource.uri(Uri.file(d['path'] as String)));
        audioMap.add(true);
      }
      indexMap.add(d['blockIndex'] as int?);
    }
    _blockIndexMap = indexMap;
    _isAudioItem = audioMap;

    // Cancel any previous focus subscription before setting up a new one.
    await _indexSub?.cancel();
    _indexSub = _player.currentIndexStream.listen((index) {
      final isAudio =
          index != null && index < _isAudioItem.length && _isAudioItem[index];
      _audioSession?.setActive(isAudio);
    });

    await _player.setLoopMode(LoopMode.off);
    // preload: false — player is ready immediately; ExoPlayer buffers ahead
    // naturally during playback instead of trying to preload thousands of
    // items upfront (which would hang for an infinite/999-pass session).
    await _player.setAudioSources(sources, preload: false);
  }

  // ── Playback Controls ───────────────────────────────────────────────────────

  Future<void> play() async => _player.play();

  Future<void> pause() async => _player.pause();

  /// Stops playback and rewinds to the beginning of the playlist.
  Future<void> stop() async {
    await _previewStateSub?.cancel();
    _previewStateSub = null;
    await _player.stop();
    await _player.seek(Duration.zero, index: 0);
    await _audioSession?.setActive(false);
  }

  /// Plays [cue] once for preview. Uses a separate player so the session
  /// player is never interrupted. Any in-progress preview is stopped first.
  Future<void> previewCue(AudioCue cue) async {
    try {
      await _previewPlayer.stop();
      // Cancel any previous completion subscription before starting a new preview.
      await _previewStateSub?.cancel();
      _previewStateSub = null;
      final source = _sourceForCue(cue);
      await _previewPlayer.setAudioSource(source, preload: true);
      await _previewPlayer.play();
      // Release audio focus once the preview finishes naturally so background
      // music (Spotify, Apple Music) stops being ducked immediately after the
      // cue ends — not held until the next explicit stop() call.
      _previewStateSub = _previewPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _audioSession?.setActive(false);
        }
      });
    } catch (e) {
      assert(() {
        // ignore: avoid_print
        print('[AudioService] previewCue() failed: $e');
        return true;
      }());
    }
  }

  // ── Disposal ────────────────────────────────────────────────────────────────

  /// Release OS audio resources. Call this when the service is no longer
  /// needed (e.g., in a [ChangeNotifier.dispose] override on the provider).
  Future<void> dispose() async {
    await _indexSub?.cancel();
    await _previewStateSub?.cancel();
    await _audioSession?.setActive(false);
    await _player.dispose();
    await _previewPlayer.dispose();
  }

  // ── Private Helpers ─────────────────────────────────────────────────────────

  /// Resolves an [AudioCue] to a just_audio [AudioSource].
  ///
  /// - Custom recordings: absolute device path → `file://` URI.
  /// - Bundled defaults: Flutter asset path stored in [AudioCue.filePath].
  AudioSource _sourceForCue(AudioCue cue) {
    final path = cue.filePath;
    if (path == null || path.isEmpty) {
      throw ArgumentError('AudioCue "${cue.name}" has no filePath set.');
    }
    if (cue.isCustom) {
      return AudioSource.uri(Uri.file(path));
    } else {
      return AudioSource.asset(path);
    }
  }
}
