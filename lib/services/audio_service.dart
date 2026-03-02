import 'dart:async';
import 'dart:math';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/audio_cue.dart';
import '../models/sequence_block.dart';
import '../models/training_session.dart';

// ── Background isolate helper ─────────────────────────────────────────────────

/// Builds warm-up and loop source descriptors, with independent random cue
/// selection for EACH loop pass. Runs in a background isolate via [compute].
///
/// Returns a [Map] with:
///   'warmup'      — List of warmup descriptors (played once before any loop)
///   'loopPasses'  — List of per-pass descriptor lists; each pass picks cues
///                   independently so a different cue plays on every iteration
///   'repeatCount' — int
///   'isInfinite'  — bool
///
/// Each descriptor Map has keys:
///   'type'       → 'silence' | 'asset' | 'file'
///   'durationMs' → int (silence only)
///   'path'       → String (asset / file only)
///   'blockIndex' → int? (index into session.sequence; null for 300 ms gaps)
Map<String, dynamic> _buildSourceDescriptors(
    Map<String, dynamic> sessionJson) {
  final session = TrainingSession.fromJson(sessionJson);
  final rng = Random();

  // Build a lookup: block.id → index in session.sequence
  final blockIndexById = <String, int>{};
  for (var i = 0; i < session.sequence.length; i++) {
    blockIndexById[session.sequence[i].id] = i;
  }

  // Split the sequence: leading WarmUpBlocks play once, everything else loops.
  final warmUpBlocks = session.sequence.whereType<WarmUpBlock>().toList();
  final loopBlocks =
      session.sequence.where((b) => b is! WarmUpBlock).toList();

  // ── Warm-up (once, not repeated) ─────────────────────────────────────────
  final warmupDescriptors = <Map<String, dynamic>>[];
  for (final block in warmUpBlocks) {
    warmupDescriptors.add({
      'type': 'silence',
      'durationMs': block.duration.inMilliseconds,
      'blockIndex': blockIndexById[block.id],
    });
  }

  // ── Per-pass loop descriptors with independent random cue picks ───────────
  // For infinite sessions: pre-build 100 passes so enough cue variety exists
  // before LoopMode.all wraps back around.
  // For finite sessions: build exactly repeatCount passes (max 99 by clamp).
  final passCount = session.isInfinite ? 100 : session.repeatCount;
  final loopPasses = <List<Map<String, dynamic>>>[];

  for (var pass = 0; pass < passCount; pass++) {
    final passDescriptors = <Map<String, dynamic>>[];
    for (var i = 0; i < loopBlocks.length; i++) {
      final block = loopBlocks[i];
      final isLastBlock = i == loopBlocks.length - 1;

      if (block is DelayBlock) {
        passDescriptors.add({
          'type': 'silence',
          'durationMs': block.duration.inMilliseconds,
          'blockIndex': blockIndexById[block.id],
        });
      } else if (block is ActionBlock) {
        // Fresh random pick for every pass — each iteration plays a
        // different cue from the pool, enabling unpredictable training.
        final cue = block.pickCue(rng);
        final path = cue.filePath;
        if (path != null && path.isNotEmpty) {
          passDescriptors.add({
            'type': cue.isCustom ? 'file' : 'asset',
            'path': path,
            'blockIndex': blockIndexById[block.id],
          });
          // 300 ms gap prevents back-to-back cues sounding like one sound.
          if (!isLastBlock) {
            passDescriptors.add({
              'type': 'silence',
              'durationMs': 300,
              'blockIndex': null, // inter-cue gap, not a named block
            });
          }
        }
      }
    }
    loopPasses.add(passDescriptors);
  }

  return {
    'warmup': warmupDescriptors,
    'loopPasses': loopPasses,
    'repeatCount': session.repeatCount,
    'isInfinite': session.isInfinite,
  };
}

/// Converts a list of source descriptor maps into parallel lists of
/// [AudioSource] objects, block-index mappings, and audio-item flags.
({List<AudioSource> sources, List<int?> indexMap, List<bool> audioMap})
    _convertDescriptors(List<Map<String, dynamic>> descs) {
  final sources = <AudioSource>[];
  final indexMap = <int?>[];
  final audioMap = <bool>[];
  for (final d in descs) {
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
  return (sources: sources, indexMap: indexMap, audioMap: audioMap);
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

  /// Number of playlist items belonging to the warm-up phase (played once).
  /// Populated by [loadSession]. Used by the UI to detect which round is active.
  int _warmupItemCount = 0;

  /// Playlist index at which each loop pass begins.
  /// `passStartIndices[0]` is the first loop-pass item (right after warm-up).
  /// Populated by [loadSession].
  List<int> _passStartIndices = const [];

  /// Retained reference to the OS audio session for dynamic focus management.
  AudioSession? _audioSession;

  /// Subscription to player index changes; drives setActive(true/false).
  StreamSubscription<int?>? _indexSub;

  /// Subscription to preview player state; releases audio focus on completion.
  StreamSubscription<PlayerState>? _previewStateSub;

  /// Completer that resolves when [init] has finished configuring the OS audio
  /// session. [loadSession] awaits this to guard against the rare fast-launch
  /// race where the user taps play before audio-session setup has completed.
  final Completer<void> _initCompleter = Completer<void>();

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

  /// Number of playlist items belonging to the one-shot warm-up phase.
  /// Items at indices `0..<warmupItemCount` are warm-up silences.
  int get warmupItemCount => _warmupItemCount;

  /// Playlist index where each loop pass starts.
  /// `passStartIndices[n]` is the first playlist index of round `n+1`.
  List<int> get passStartIndices => List.unmodifiable(_passStartIndices);

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
    } finally {
      // Mark init as complete regardless of success/failure so loadSession()
      // is never blocked indefinitely by a failed audio-session handshake.
      if (!_initCompleter.isCompleted) _initCompleter.complete();
    }
  }

  // ── Session Compiler ────────────────────────────────────────────────────────

  /// Compiles [session] into a just_audio playlist and loads it, ready for
  /// an immediate [play] call.
  ///
  /// The heavy descriptor-building work runs in a background isolate via
  /// [compute] to avoid blocking the main thread ([CORE-01]).
  ///
  /// Each loop pass picks cues independently so a different cue plays on
  /// every iteration when an ActionBlock has multiple sounds.
  ///
  ///   • finite sessions  → all [repeatCount] passes unrolled, [LoopMode.off]
  ///                        (warm-up plays exactly once; max 99 passes × N blocks)
  ///   • infinite sessions → 100 pre-built passes, [LoopMode.all]; the 100-pass
  ///                         super-period provides good variety before repeating
  Future<void> loadSession(TrainingSession session) async {
    // Wait for init() to finish so the OS audio session is configured before
    // playback begins. No-op in the normal case (init completes in ~50ms,
    // well before the user can navigate to and tap play on a session).
    if (!_initCompleter.isCompleted) await _initCompleter.future;

    // Ensure the player is idle before loading new sources to avoid
    // ExoPlayer's internal operation queue deadlocking.
    await _player.stop();

    final result = await compute(_buildSourceDescriptors, session.toJson());

    final warmupDescs =
        (result['warmup'] as List).cast<Map<String, dynamic>>();
    final loopPassesRaw = result['loopPasses'] as List;
    final loopPasses = loopPassesRaw
        .map((p) => (p as List).cast<Map<String, dynamic>>())
        .toList();
    final isInfinite = result['isInfinite'] as bool;

    final warmup = _convertDescriptors(warmupDescs);
    // Convert each pass separately — different cue files per pass.
    final convertedPasses = loopPasses.map(_convertDescriptors).toList();

    // Finite sessions: all passes are unrolled inline (LoopMode.off) so the
    // warm-up plays exactly once and audio-focus management is correct.
    // Infinite sessions: 100 pre-built passes use LoopMode.all; the 100-pass
    // "super-period" provides good cue variety before the cycle repeats.
    final useNativeLoop = isInfinite;

    _blockIndexMap = [
      ...warmup.indexMap,
      for (final p in convertedPasses) ...p.indexMap,
    ];
    _isAudioItem = [
      ...warmup.audioMap,
      for (final p in convertedPasses) ...p.audioMap,
    ];

    // Populate round-tracking helpers used by the active-session UI.
    _warmupItemCount = warmup.sources.length;
    var passStart = _warmupItemCount;
    final passStarts = <int>[];
    for (final p in convertedPasses) {
      passStarts.add(passStart);
      passStart += p.sources.length;
    }
    _passStartIndices = passStarts;

    // Cancel any previous focus subscription before setting up a new one.
    await _indexSub?.cancel();
    _indexSub = _player.currentIndexStream.listen((index) {
      final isAudio =
          index != null && index < _isAudioItem.length && _isAudioItem[index];
      _audioSession?.setActive(isAudio);
    });

    final allSources = [
      ...warmup.sources,
      for (final p in convertedPasses) ...p.sources,
    ];

    await _player.setLoopMode(useNativeLoop ? LoopMode.all : LoopMode.off);
    // preload: false — player is ready immediately; ExoPlayer buffers ahead
    // naturally during playback. Source count is bounded: max 99 passes × N
    // blocks for finite, or 100 passes × N blocks for infinite.
    await _player.setAudioSources(allSources, preload: false);
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
