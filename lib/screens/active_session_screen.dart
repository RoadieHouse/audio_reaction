import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../models/sequence_block.dart';
import '../models/training_session.dart';
import '../services/audio_service.dart';

// ── Phase label helper ────────────────────────────────────────────────────────

String _phaseLabel(SequenceBlock block) {
  if (block is WarmUpBlock) return 'WARM UP';
  if (block is DelayBlock) return 'DELAY';
  if (block is ActionBlock) {
    return block.audioCues.isNotEmpty
        ? block.audioCues.first.name.toUpperCase()
        : 'ACTION';
  }
  return '';
}

/// Distraction-free active session screen.
/// Features a screen-filling countdown timer, phase indicator, and controls.
///
/// [CORE-01]: All timing is handled by just_audio natively via SilenceAudioSource
/// playlist items — no Dart Timer/Future.delayed used, so playback survives
/// screen lock and backgrounding on both iOS and Android.
class ActiveSessionScreen extends StatefulWidget {
  const ActiveSessionScreen({super.key, this.session});

  static const routeName = '/active';

  final TrainingSession? session;

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  late final AudioService _audio;
  late final StreamSubscription<PlayerState> _stateSub;
  bool _didExit = false;
  bool _loading = true;

  /// Single exit point for all navigation-away paths.
  /// Guards against duplicate pops from simultaneous stream events.
  void _guardedExit() {
    if (_didExit) return;
    _didExit = true;
    _audio.stop().then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void initState() {
    super.initState();
    _audio = context.read<AudioService>();

    // Subscribe to completion BEFORE loading so no event is missed.
    _stateSub = _audio.playerStateStream.listen((state) {
      // Only respond to completion once fully loaded and playing.
      if (!_loading && state.processingState == ProcessingState.completed) {
        _guardedExit();
      }
    });

    // Guard: pop immediately if no session was passed.
    if (widget.session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }

    // Load playlist and start playback after the first frame renders so the
    // loading overlay is visible before any heavy work begins.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await _audio.loadSession(widget.session!);
        if (!mounted) return;
        await _audio.play();
      } catch (e) {
        assert(() {
          // ignore: avoid_print
          print('[ActiveSession] load/play failed: $e');
          return true;
        }());
        _guardedExit();
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  @override
  void dispose() {
    _stateSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) {
        if (didPop) return;
        _guardedExit();
      },
      child: Scaffold(
        // Pure black — maximum contrast for outdoor visibility
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              // ── Session content ──────────────────────────────────────────
              Column(
                children: [
                  // ── Top Bar (back + session name) ────────────────────────
                  _TopBar(
                    sessionName: widget.session?.title ?? 'Session',
                    onBack: _guardedExit,
                  ),

                  // ── Timer ────────────────────────────────────────────────
                  Expanded(
                    child: StreamBuilder<Duration>(
                      stream: _audio.positionStream,
                      initialData: Duration.zero,
                      builder: (_, posSnap) => StreamBuilder<Duration?>(
                        stream: _audio.currentDurationStream,
                        builder: (_, durSnap) {
                          final pos = posSnap.data ?? Duration.zero;
                          final dur = durSnap.data;
                          // Show time remaining in current block; fall back to
                          // elapsed if duration is unknown (e.g., still loading).
                          Duration display;
                          if (dur != null) {
                            final remaining = dur - pos;
                            display = remaining.isNegative ? Duration.zero : remaining;
                          } else {
                            display = pos;
                          }
                          return _TimerDisplay(remaining: display);
                        },
                      ),
                    ),
                  ),

                  // ── Phase Label ──────────────────────────────────────────
                  StreamBuilder<int?>(
                    stream: _audio.currentIndexStream,
                    initialData: 0,
                    builder: (_, snap) {
                      final blocks = widget.session?.sequence ?? const [];
                      final playlistIdx = snap.data ?? 0;
                      final map = _audio.blockIndexMap;
                      final blockIdx = (playlistIdx < map.length)
                          ? map[playlistIdx]
                          : null;
                      final label = (blockIdx != null && blockIdx < blocks.length)
                          ? _phaseLabel(blocks[blockIdx])
                          : '';
                      return _PhaseLabel(phase: label);
                    },
                  ),

                  const SizedBox(height: 32),

                  // ── Controls ─────────────────────────────────────────────
                  _SessionControls(audio: _audio, onStop: _guardedExit),

                  const SizedBox(height: 40),
                ],
              ),

              // ── Loading overlay (shown while playlist buffers) ───────────
              if (_loading)
                Container(
                  color: Colors.black,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 20),
                        Text(
                          'Loading session…',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.session?.title ?? '',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Top Bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.sessionName, required this.onBack});

  final String sessionName;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // Back/Stop — 64×64 tap target
          SizedBox(
            width: 64,
            height: 64,
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              color: theme.colorScheme.onSurface,
              tooltip: 'Stop & Back',
            ),
          ),
          Expanded(
            child: Text(
              sessionName,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Spacer to balance the back button
          const SizedBox(width: 64),
        ],
      ),
    );
  }
}

// ── Timer Display ─────────────────────────────────────────────────────────────

class _TimerDisplay extends StatelessWidget {
  const _TimerDisplay({required this.remaining});

  final Duration remaining;

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      // Horizontal padding so the timer doesn't hit the edge
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: FittedBox(
        fit: BoxFit.contain,
        child: Text(
          _fmt(remaining),
          style: theme.textTheme.displayLarge?.copyWith(
            // Explicit enormous base size — FittedBox scales it to fill the space
            fontSize: 200,
          ),
        ),
      ),
    );
  }
}

// ── Phase Label ───────────────────────────────────────────────────────────────

class _PhaseLabel extends StatelessWidget {
  const _PhaseLabel({required this.phase});

  final String phase;

  @override
  Widget build(BuildContext context) {
    return Text(phase, style: Theme.of(context).textTheme.titleLarge);
  }
}

// ── Session Controls ──────────────────────────────────────────────────────────

class _SessionControls extends StatelessWidget {
  const _SessionControls({required this.audio, required this.onStop});

  final AudioService audio;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Pause/Resume Button — driven by playingStream
        StreamBuilder<bool>(
          stream: audio.playingStream,
          initialData: true,
          builder: (context, snap) {
            final isPlaying = snap.data ?? true;
            return _LargeControlButton(
              icon: isPlaying
                  ? Icons.pause_circle_rounded
                  : Icons.play_circle_rounded,
              label: isPlaying ? 'Pause' : 'Resume',
              onPressed: isPlaying
                  ? () => audio.pause()
                  : () => audio.play(),
            );
          },
        ),

        // Stop Button — uses the single guarded exit path
        _LargeControlButton(
          icon: Icons.stop_circle_rounded,
          label: 'Stop',
          onPressed: onStop,
          color: Colors.redAccent,
        ),
      ],
    );
  }
}

// ── Large Control Button ──────────────────────────────────────────────────────

class _LargeControlButton extends StatelessWidget {
  const _LargeControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = color ?? theme.colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 96,
          height: 96,
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, size: 72, color: iconColor),
            tooltip: label,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(letterSpacing: 1),
        ),
      ],
    );
  }
}

