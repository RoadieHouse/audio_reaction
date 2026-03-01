import 'package:flutter/material.dart';
import '../models/training_session.dart';

/// Distraction-free active session screen.
/// Features a screen-filling countdown timer, phase indicator, and controls.
///
/// [CORE-01] NOTE: In production, the timer logic must NOT use Dart's
/// Timer/Future.delayed (these are suspended when screen locks). A
/// background-safe approach (e.g., pre-built audio playlist with silent gaps)
/// must be used. This screen is a visual prototype only.
class ActiveSessionScreen extends StatelessWidget {
  const ActiveSessionScreen({super.key, this.session});

  static const routeName = '/active';

  final TrainingSession? session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Pure black — maximum contrast for outdoor visibility
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar (back + session name) ────────────────────────────
            _TopBar(sessionName: session?.title ?? 'Session'),

            // ── Timer ────────────────────────────────────────────────────
            const Expanded(child: _TimerDisplay()),

            // ── Phase Label ──────────────────────────────────────────────
            const _PhaseLabel(phase: 'SPRINTING'),

            const SizedBox(height: 32),

            // ── Controls ─────────────────────────────────────────────────
            const _SessionControls(),

            const SizedBox(height: 40),
          ],
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
  const _TimerDisplay();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      // Horizontal padding so the timer doesn't hit the edge
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: FittedBox(
        fit: BoxFit.contain,
        child: Text(
          '00:45',
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
  const _SessionControls();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Pause Button
        _LargeControlButton(
          icon: Icons.pause_circle_rounded,
          label: 'Pause',
          onPressed: () {}, // dummy
        ),

        // Stop Button
        _LargeControlButton(
          icon: Icons.stop_circle_rounded,
          label: 'Stop',
          onPressed: () => Navigator.of(context).pop(),
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
