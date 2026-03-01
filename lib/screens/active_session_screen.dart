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
/// [CORE-01] NOTE: In production, the timer logic must NOT use Dart's
/// Timer/Future.delayed (these are suspended when screen locks). A
/// background-safe approach (e.g., pre-built audio playlist with silent gaps)
/// must be used. This screen is a visual prototype only.
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

  @override
  void initState() {
    super.initState();
    _audio = context.read<AudioService>();
    _stateSub = _audio.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _audio.stop();
        if (mounted) Navigator.of(context).pop();
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
      onPopInvokedWithResult: (bool didPop, _) async {
        if (didPop) return;
        await _audio.stop();
        if (mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        // Pure black — maximum contrast for outdoor visibility
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              // ── Top Bar (back + session name) ──────────────────────────
              _TopBar(sessionName: widget.session?.title ?? 'Session'),

              // ── Timer ──────────────────────────────────────────────────
              Expanded(
                child: StreamBuilder<Duration>(
                  stream: _audio.positionStream,
                  initialData: Duration.zero,
                  builder: (_, snap) =>
                      _TimerDisplay(elapsed: snap.data ?? Duration.zero),
                ),
              ),

              // ── Phase Label ────────────────────────────────────────────
              StreamBuilder<int?>(
                stream: _audio.currentIndexStream,
                initialData: 0,
                builder: (_, snap) {
                  final blocks = widget.session?.sequence ?? const [];
                  final idx = snap.data ?? 0;
                  final label = blocks.isEmpty
                      ? ''
                      : _phaseLabel(blocks[idx % blocks.length]);
                  return _PhaseLabel(phase: label);
                },
              ),

              const SizedBox(height: 32),

              // ── Controls ───────────────────────────────────────────────
              _SessionControls(audio: _audio),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Top Bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.sessionName});

  final String sessionName;

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
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              color: theme.colorScheme.onSurface,
              tooltip: 'Back',
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
  const _TimerDisplay({required this.elapsed});

  final Duration elapsed;

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
          _fmt(elapsed),
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
  const _SessionControls({required this.audio});

  final AudioService audio;

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

        // Stop Button
        _LargeControlButton(
          icon: Icons.stop_circle_rounded,
          label: 'Stop',
          onPressed: () async {
            await audio.stop();
            if (context.mounted) Navigator.of(context).pop();
          },
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

