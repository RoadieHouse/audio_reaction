import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../models/sequence_block.dart';
import '../models/training_session.dart';
import '../services/audio_service.dart';
import '../theme/app_theme.dart';

// ── Phase helpers ─────────────────────────────────────────────────────────────

String _phaseLabel(SequenceBlock? block) {
  if (block is WarmUpBlock) return 'WARM UP';
  if (block is DelayBlock) return 'REST';
  if (block is ActionBlock) return 'ACTION';
  return '';
}

/// Returns [brandAccent] for action blocks (high-intensity cue), otherwise
/// [textPrimary] (white) so the ring subtly shifts colour when a cue fires.
Color _phaseRingColor(SequenceBlock? block, ColorScheme cs) =>
    block is ActionBlock ? AppTheme.brandAccent : AppTheme.textPrimary;

String _fmt(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Distraction-free active session screen.
///
/// [CORE-01]: All training timing is driven by just_audio's native playlist
/// (SilenceAudioSource items). The UI uses a [Stopwatch] only for display
/// purposes — the audio sequence is completely unaffected by screen lock.
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
  late final StreamSubscription<bool> _playingSub;
  late final StreamSubscription<int?> _indexSub;

  bool _didExit = false;
  bool _isPlaying = false;
  int _playlistIdx = 0;

  /// Wall-clock elapsed time — used only for the UI countdown/countup.
  /// The audio timeline is independent and survives screen lock [CORE-01].
  final Stopwatch _watch = Stopwatch();
  Timer? _ticker;

  // ── Exit ──────────────────────────────────────────────────────────────────

  void _guardedExit() {
    if (_didExit) return;
    _didExit = true;
    _ticker?.cancel();
    _watch.stop();
    _audio.stop().then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _audio = context.read<AudioService>();

    // Detect natural playlist completion before loading, so no event is missed.
    _stateSub = _audio.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) _guardedExit();
    });

    // Sync the Stopwatch with the player playing/paused state.
    _playingSub = _audio.playingStream.listen((playing) {
      if (!mounted) return;
      setState(() => _isPlaying = playing);
      if (playing) {
        _watch.start();
        _ticker ??= Timer.periodic(const Duration(milliseconds: 200), (_) {
          if (mounted) setState(() {});
        });
      } else {
        _watch.stop();
      }
    });

    // Track the current playlist index for phase/round labels.
    _indexSub = _audio.currentIndexStream.listen((idx) {
      if (mounted) setState(() => _playlistIdx = idx ?? 0);
    });

    if (widget.session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _audio
          .loadSession(widget.session!)
          .then((_) {
            if (mounted) _audio.play();
          })
          .catchError((Object e) {
            assert(() {
              // ignore: avoid_print
              print('[ActiveSession] load/play failed: $e');
              return true;
            }());
            if (mounted) _guardedExit();
          });
    });
  }

  @override
  void dispose() {
    _stateSub.cancel();
    _playingSub.cancel();
    _indexSub.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  // ── Derived helpers ───────────────────────────────────────────────────────

  /// Best-effort total session duration: uses persisted value, then falls back
  /// to the computed helper (warmup + delays × rounds).
  Duration get _sessionTotal {
    final d = widget.session?.totalDuration ?? Duration.zero;
    return d == Duration.zero
        ? (widget.session?.computedDuration ?? Duration.zero)
        : d;
  }

  /// For finite sessions: time remaining. For infinite: elapsed.
  Duration get _displayTime {
    if (widget.session?.isInfinite ?? false) return _watch.elapsed;
    final remaining = _sessionTotal - _watch.elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Ring fill fraction (0.0–1.0). Returns null for infinite sessions,
  /// signalling an indeterminate ring state.
  double? get _ringProgress {
    if (widget.session?.isInfinite ?? false) return null;
    final totalMs = _sessionTotal.inMilliseconds;
    if (totalMs == 0) return null;
    return (_watch.elapsed.inMilliseconds / totalMs).clamp(0.0, 1.0);
  }

  /// Current [SequenceBlock] being played, derived from the playlist index.
  SequenceBlock? get _currentBlock {
    final map = _audio.blockIndexMap;
    if (_playlistIdx >= map.length) return null;
    final blockIdx = map[_playlistIdx];
    if (blockIdx == null) return null;
    final seq = widget.session?.sequence;
    if (seq == null || blockIdx >= seq.length) return null;
    return seq[blockIdx];
  }

  /// Short label describing the current position in the session, e.g.
  /// "WARM UP", "ROUND 1 OF 3", or "ROUND 4" for infinite sessions.
  String get _roundLabel {
    final session = widget.session;
    if (session == null) return '';
    if (_playlistIdx < _audio.warmupItemCount) return 'WARM UP';
    final passes = _audio.passStartIndices;
    if (passes.isEmpty) return '';
    int passIdx = 0;
    for (int i = passes.length - 1; i >= 0; i--) {
      if (_playlistIdx >= passes[i]) {
        passIdx = i;
        break;
      }
    }
    final round = passIdx + 1;
    return session.isInfinite
        ? 'ROUND $round'
        : 'ROUND $round OF ${session.repeatCount}';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final block = _currentBlock;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) {
        if (didPop) return;
        _guardedExit();
      },
      child: Scaffold(
        backgroundColor: AppTheme.bgBase,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 8),
              _Header(
                title: widget.session?.title ?? 'Session',
                roundLabel: _roundLabel,
                isInfinite: widget.session?.isInfinite ?? false,
                onBack: _guardedExit,
              ),
              const SizedBox(height: 16),
              // Ring takes all remaining vertical + horizontal space.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = math.min(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      return Center(
                        child: SizedBox.square(
                          dimension: size,
                          child: _SessionRing(
                            progress: _ringProgress,
                            ringColor: _phaseRingColor(block, cs),
                            displayTime: _displayTime,
                            phase: _phaseLabel(block),
                            showElapsed: widget.session?.isInfinite ?? false,
                            isPlaying: _isPlaying,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 28),
              _Controls(
                audio: _audio,
                isPlaying: _isPlaying,
                onStop: _guardedExit,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.roundLabel,
    required this.isInfinite,
    required this.onBack,
  });

  final String title;
  final String roundLabel;
  final bool isInfinite;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // Title row with back button
        Stack(
          alignment: Alignment.center,
          children: [
            // Back button — left-aligned
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 56,
                height: 48,
                child: IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.chevron_left_rounded, size: 30),
                  color: theme.colorScheme.onSurface,
                  tooltip: 'Stop & Back',
                ),
              ),
            ),
            // Session title — centered, padded away from both sides
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 68),
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            // ∞ badge — right-aligned, mirrors the back button position
            if (isInfinite)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.all_inclusive_rounded,
                      size: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        // Round indicator — standalone centered text, no extra elements
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: Text(
            roundLabel,
            key: ValueKey(roundLabel),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              letterSpacing: 2.0,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Session Ring ──────────────────────────────────────────────────────────────

/// Circular progress ring with the countdown timer and phase label inside.
///
/// For finite sessions, [progress] drives a [CustomPainter] arc.
/// For infinite sessions ([progress] == null), a slow-rotating short arc
/// provides a calm "in-progress" indication without the frantic default spinner.
class _SessionRing extends StatefulWidget {
  const _SessionRing({
    required this.progress,
    required this.ringColor,
    required this.displayTime,
    required this.phase,
    required this.showElapsed,
    required this.isPlaying,
  });

  /// 0.0–1.0 for finite sessions; null = infinite (indeterminate).
  final double? progress;
  final Color ringColor;
  final Duration displayTime;
  final String phase;

  /// True for infinite sessions: displays "ELAPSED" label below the time.
  final bool showElapsed;

  /// When false the slow-rotation arc is paused.
  final bool isPlaying;

  @override
  State<_SessionRing> createState() => _SessionRingState();
}

class _SessionRingState extends State<_SessionRing>
    with SingleTickerProviderStateMixin {
  /// Drives the slow arc rotation for infinite sessions.
  AnimationController? _rotCtrl;

  static const double _strokeWidth = 10;

  @override
  void initState() {
    super.initState();
    _startOrStopRotation();
  }

  @override
  void didUpdateWidget(_SessionRing old) {
    super.didUpdateWidget(old);
    if (old.progress != widget.progress) _startOrStopRotation();
    // Pause/resume the arc when the session is paused/resumed.
    if (old.isPlaying != widget.isPlaying && _rotCtrl != null) {
      widget.isPlaying ? _rotCtrl!.repeat() : _rotCtrl!.stop();
    }
  }

  void _startOrStopRotation() {
    if (widget.progress == null) {
      // Infinite session — spin a short arc very slowly (7 s per rotation).
      _rotCtrl ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 7000),
      );
      // Only repeat if the session is currently playing.
      if (widget.isPlaying) _rotCtrl!.repeat();
    } else {
      _rotCtrl?.stop();
      _rotCtrl?.dispose();
      _rotCtrl = null;
    }
  }

  @override
  void dispose() {
    _rotCtrl?.dispose();
    super.dispose();
  }

  Widget _ring(BuildContext context) {
    final trackColor = Theme.of(context).colorScheme.surfaceContainerHighest;

    if (widget.progress == null) {
      // Infinite: static track + slow-rotating ~75° arc (calm sweep).
      return Stack(
        children: [
          SizedBox.expand(
            child: CustomPaint(
              painter: _RingPainter(
                progress: 0,
                ringColor: Colors.transparent,
                trackColor: trackColor,
                strokeWidth: _strokeWidth,
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _rotCtrl!,
            builder: (_, _) => SizedBox.expand(
              child: CustomPaint(
                painter: _ArcSweepPainter(
                  startAngle:
                      -math.pi / 2 + _rotCtrl!.value * 2 * math.pi,
                  sweepAngle: math.pi / 2.4, // ≈ 75°
                  color: AppTheme.textPrimary.withValues(alpha: 0.35),
                  strokeWidth: _strokeWidth,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Finite: smooth color transition when phase changes (warm-up ↔ action).
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: widget.ringColor),
      duration: const Duration(milliseconds: 400),
      builder: (_, color, _) => CustomPaint(
        painter: _RingPainter(
          progress: widget.progress!,
          ringColor: color ?? AppTheme.textPrimary,
          trackColor: trackColor,
          strokeWidth: _strokeWidth,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        // Ring layer
        SizedBox.expand(child: _ring(context)),
        // Timer content centered inside the ring
        Positioned.fill(
          child: Padding(
            // Keep text well clear of the stroke.
            padding: const EdgeInsets.all(36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Large countdown / count-up — FittedBox scales to fill width.
                FittedBox(
                  fit: BoxFit.contain,
                  child: Text(
                    _fmt(widget.displayTime),
                    style: theme.textTheme.displayLarge?.copyWith(
                      color: AppTheme.textPrimary,
                      // Fixed-width digits prevent jitter as numbers change.
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                if (widget.showElapsed)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'ELAPSED',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                // Phase label — cross-fades on phase change.
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    widget.phase,
                    key: ValueKey(widget.phase),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppTheme.textSecondary,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Ring Painter ──────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
    this.strokeWidth = 10,
  });

  final double progress;
  final Color ringColor;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Inset radius so the stroke stays entirely within the canvas bounds.
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track — full circle, always drawn.
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = trackColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Progress arc — clockwise from the 12-o'clock position.
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    if (sweep > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..color = ringColor
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      progress != old.progress ||
      ringColor != old.ringColor ||
      trackColor != old.trackColor;
}

// ── Arc Sweep Painter (infinite sessions) ────────────────────────────────────

/// Draws a single short arc at [startAngle] with the given [sweepAngle].
/// Used for the calm slow-rotating indicator in infinite-round sessions.
class _ArcSweepPainter extends CustomPainter {
  const _ArcSweepPainter({
    required this.startAngle,
    required this.sweepAngle,
    required this.color,
    this.strokeWidth = 10,
  });

  final double startAngle;
  final double sweepAngle;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ArcSweepPainter old) =>
      startAngle != old.startAngle || color != old.color;
}

// ── Controls ──────────────────────────────────────────────────────────────────

class _Controls extends StatelessWidget {
  const _Controls({
    required this.audio,
    required this.isPlaying,
    required this.onStop,
  });

  final AudioService audio;
  final bool isPlaying;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // ── Stop (secondary, outlined circle) ─────────────────────────────
        SizedBox.square(
          dimension: 60,
          child: Material(
            color: cs.surface,
            shape: CircleBorder(
              side: BorderSide(
                color: cs.outlineVariant,
                width: 1.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onStop,
              child: Icon(
                Icons.stop_rounded,
                color: cs.onSurfaceVariant,
                size: 26,
              ),
            ),
          ),
        ),
        const SizedBox(width: 36),
        // ── Play / Pause (primary, brandAccent, 80×80) ────────────────────
        SizedBox.square(
          dimension: 80,
          child: Material(
            color: cs.primary,
            shape: const CircleBorder(),
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: isPlaying ? audio.pause : audio.play,
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: cs.onPrimary,
                size: 40,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

