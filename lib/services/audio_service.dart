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
/// Returns a list of Maps with keys:
///   'type'       → 'silence' | 'asset' | 'file'
///   'durationMs' → int (silence only)
///   'path'       → String (asset / file only)
List<Map<String, dynamic>> _buildSourceDescriptors(
    Map<String, dynamic> sessionJson) {
  final session = TrainingSession.fromJson(sessionJson);
  final rng = Random();
  final descriptors = <Map<String, dynamic>>[];
  final passes = session.isInfinite ? 1 : session.repeatCount;

  for (var pass = 0; pass < passes; pass++) {
    final blocks = session.sequence;
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      final isLastBlock = (pass == passes - 1) && (i == blocks.length - 1);

      if (block is WarmUpBlock) {
        descriptors.add({
          'type': 'silence',
          'durationMs': block.duration.inMilliseconds,
        });
      } else if (block is DelayBlock) {
        descriptors.add({
          'type': 'silence',
          'durationMs': block.duration.inMilliseconds,
        });
      } else if (block is ActionBlock) {
        final cue = block.pickCue(rng);
        final path = cue.filePath;
        if (path != null && path.isNotEmpty) {
          descriptors.add({
            'type': cue.isCustom ? 'file' : 'asset',
            'path': path,
          });
          // 300 ms gap prevents back-to-back cues sounding like one sound.
          if (!isLastBlock) {
            descriptors.add({'type': 'silence', 'durationMs': 300});
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

  // ── Public Streams ──────────────────────────────────────────────────────────

  /// Real-time playback position within the current playlist item.
  /// Wire this to the UI countdown timer to show exact remaining time.
  Stream<Duration> get positionStream => _player.positionStream;

  /// Index of the currently playing item in the compiled playlist.
  /// Cross-reference with the block index map (built in [loadSession]) to
  /// know which [SequenceBlock] is active.
  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  /// Whether the player is currently playing (not paused, not stopped).
  Stream<bool> get playingStream => _player.playingStream;

  /// Full player state including ProcessingState (idle, loading, buffering,
  /// ready, completed). Use to detect when a finite session ends.
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  // ── Initialisation ──────────────────────────────────────────────────────────

  /// Configures the OS audio session so cues mix with background music.
  ///
  /// Call once at app start (e.g., inside [main] or when this service is
  /// first provided) before any call to [loadSession] or [play].
  Future<void> init() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(
        AudioSessionConfiguration(
          // ── iOS ────────────────────────────────────────────────────────────
          // AVAudioSessionCategoryAmbient + mixWithOthers lets our cues play
          // alongside Spotify / Apple Music without requesting audio focus,
          // so iOS never pauses the user's background music.
          avAudioSessionCategory: AVAudioSessionCategory.ambient,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.mixWithOthers,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,

          // ── Android ────────────────────────────────────────────────────────
          // USAGE_ASSISTANCE_SONIFICATION signals short, notification-style
          // cues to the OS. gainTransientMayDuck asks for a brief focus grant:
          // Spotify ducks its volume slightly for the cue, then immediately
          // resumes — it never stops or pauses.
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.sonification,
            usage: AndroidAudioUsage.assistanceSonification,
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
    final descriptors =
        await compute(_buildSourceDescriptors, session.toJson());

    final sources = <AudioSource>[];
    for (final d in descriptors) {
      final type = d['type'] as String;
      if (type == 'silence') {
        sources.add(SilenceAudioSource(
          duration: Duration(milliseconds: d['durationMs'] as int),
        ));
      } else if (type == 'asset') {
        sources.add(AudioSource.asset(d['path'] as String));
      } else if (type == 'file') {
        sources.add(AudioSource.uri(Uri.file(d['path'] as String)));
      }
    }

    await _player.setLoopMode(
        session.isInfinite ? LoopMode.all : LoopMode.off);
    await _player.setAudioSources(sources, preload: true);
  }

  // ── Playback Controls ───────────────────────────────────────────────────────

  Future<void> play() async => _player.play();

  Future<void> pause() async => _player.pause();

  /// Stops playback and rewinds to the beginning of the playlist.
  Future<void> stop() async {
    await _player.stop();
    await _player.seek(Duration.zero, index: 0);
  }

  /// Plays [cue] once for preview. Uses a separate player so the session
  /// player is never interrupted. Any in-progress preview is stopped first.
  Future<void> previewCue(AudioCue cue) async {
    try {
      await _previewPlayer.stop();
      final source = _sourceForCue(cue);
      await _previewPlayer.setAudioSource(source);
      await _previewPlayer.play();
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
