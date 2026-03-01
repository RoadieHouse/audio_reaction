import 'dart:math';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../models/audio_cue.dart';
import '../models/sequence_block.dart';
import '../models/training_session.dart';

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

  // ── Public Streams ──────────────────────────────────────────────────────────

  /// Real-time playback position within the current playlist item.
  /// Wire this to the UI countdown timer to show exact remaining time.
  Stream<Duration> get positionStream => _player.positionStream;

  /// Index of the currently playing item in the compiled playlist.
  /// Cross-reference with the block index map (built in [loadSession]) to
  /// know which [SequenceBlock] is active.
  Stream<int?> get currentIndexStream => _player.currentIndexStream;

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
  /// Loop strategy:
  /// - [TrainingSession.isInfinite] → build one pass, then engage
  ///   [LoopMode.all] so just_audio repeats natively without duplicating
  ///   sources. Safe under screen lock ([CORE-01]).
  /// - Finite → unroll the sequence [TrainingSession.repeatCount] times into
  ///   one flat [sources] list and set [LoopMode.off].
  ///
  /// Cue selection per [ActionBlock] is randomised fresh on every call so
  /// each training run is unpredictable.
  Future<void> loadSession(TrainingSession session) async {
    final rng = Random();
    final sources = <AudioSource>[];

    if (session.isInfinite) {
      // One pass — LoopMode.all handles repetition inside the audio engine.
      for (final block in session.sequence) {
        _appendBlock(block, sources, rng);
      }
      await _player.setLoopMode(LoopMode.all);
    } else {
      // Mathematically unroll: repeat the sequence repeatCount times.
      for (var i = 0; i < session.repeatCount; i++) {
        for (final block in session.sequence) {
          _appendBlock(block, sources, rng);
        }
      }
      await _player.setLoopMode(LoopMode.off);
    }

    await _player.setAudioSources(sources, preload: false);
  }

  // ── Playback Controls ───────────────────────────────────────────────────────

  Future<void> play() async => _player.play();

  Future<void> pause() async => _player.pause();

  /// Stops playback and rewinds to the beginning of the playlist.
  Future<void> stop() async {
    await _player.stop();
    await _player.seek(Duration.zero, index: 0);
  }

  // ── Disposal ────────────────────────────────────────────────────────────────

  /// Release OS audio resources. Call this when the service is no longer
  /// needed (e.g., in a [ChangeNotifier.dispose] override on the provider).
  Future<void> dispose() async => _player.dispose();

  // ── Private Helpers ─────────────────────────────────────────────────────────

  /// Appends the correct [AudioSource] for [block] to [sources].
  ///
  /// Extracted so both the infinite (single-pass) and finite (unrolled) paths
  /// in [loadSession] share identical block-handling logic.
  void _appendBlock(SequenceBlock block, List<AudioSource> sources, Random rng) {
    if (block is WarmUpBlock) {
      // Silent gap — just_audio advances after the duration elapses, keeping
      // timing accurate even under screen lock [CORE-01].
      sources.add(SilenceAudioSource(duration: block.duration));
    } else if (block is DelayBlock) {
      sources.add(SilenceAudioSource(duration: block.duration));
    } else if (block is ActionBlock) {
      // Random cue selection — unpredictable per run.
      final cue = block.pickCue(rng);
      try {
        sources.add(_sourceForCue(cue));
      } catch (e) {
        assert(() {
          // ignore: avoid_print
          print('[AudioService] Skipping cue "${cue.name}": $e');
          return true;
        }());
        // Skip the bad cue; a missing file should not abort the whole session.
      }
    }
  }

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
