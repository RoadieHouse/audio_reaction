import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/audio_cue.dart';
import '../../models/sequence_block.dart';
import '../../theme/app_theme.dart';

// ── WarmUpCard ────────────────────────────────────────────────────────────────

/// Card for a [WarmUpBlock]. Exposes a numeric duration field.
/// Callbacks are wired to the Provider in a future step.
class WarmUpCard extends StatelessWidget {
  const WarmUpCard({
    super.key,
    required this.block,
    this.onDurationChanged,
    this.onDelete,
  });

  final WarmUpBlock block;
  final ValueChanged<int>? onDurationChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return _BlockShell(
      accentColor: AppTheme.blockWarmUp,
      typeLabel: 'WARM-UP',
      onDelete: onDelete,
      child: _DurationField(
        initialSeconds: block.duration.inSeconds,
        onChanged: onDurationChanged,
      ),
    );
  }
}

// ── DelayCard ─────────────────────────────────────────────────────────────────

/// Card for a [DelayBlock]. Exposes a numeric duration field.
class DelayCard extends StatelessWidget {
  const DelayCard({
    super.key,
    required this.block,
    this.onDurationChanged,
    this.onDelete,
  });

  final DelayBlock block;
  final ValueChanged<int>? onDurationChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return _BlockShell(
      accentColor: AppTheme.blockDelay,
      typeLabel: 'DELAY',
      onDelete: onDelete,
      child: _DurationField(
        initialSeconds: block.duration.inSeconds,
        onChanged: onDurationChanged,
      ),
    );
  }
}

// ── ActionCard ────────────────────────────────────────────────────────────────

/// Card for an [ActionBlock]. Shows the assigned [AudioCue] names as chips
/// and an "Add Sound" button that triggers [onAddSound].
class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.block,
    this.onAddSound,
    this.onDelete,
  });

  final ActionBlock block;
  final VoidCallback? onAddSound;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return _BlockShell(
      accentColor: AppTheme.blockAction,
      typeLabel: 'ACTION',
      onDelete: onDelete,
      child: _CueRow(cues: block.audioCues, onAddSound: onAddSound),
    );
  }
}

// ── Shared Shell ──────────────────────────────────────────────────────────────

class _BlockShell extends StatelessWidget {
  const _BlockShell({
    required this.accentColor,
    required this.typeLabel,
    required this.child,
    this.onDelete,
  });

  final Color accentColor;
  final String typeLabel;
  final Widget child;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: accentColor, width: 3)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TypeLabel(label: typeLabel, color: accentColor),
                  const SizedBox(height: 10),
                  child,
                ],
              ),
            ),
            // Delete — 48×48 minimum tap target [UI-02]
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.remove_circle_outline_rounded,
                  color: theme.colorScheme.error.withValues(alpha: 0.7),
                  size: 22,
                ),
                onPressed: onDelete,
                tooltip: 'Remove block',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Type Label Chip ───────────────────────────────────────────────────────────

class _TypeLabel extends StatelessWidget {
  const _TypeLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ── Duration Field ────────────────────────────────────────────────────────────

/// Numeric [TextField] for seconds. Manages its own [TextEditingController]
/// so WarmUpCard / DelayCard can remain [StatelessWidget].
class _DurationField extends StatefulWidget {
  const _DurationField({required this.initialSeconds, this.onChanged});

  final int initialSeconds;
  final ValueChanged<int>? onChanged;

  @override
  State<_DurationField> createState() => _DurationFieldState();
}

class _DurationFieldState extends State<_DurationField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialSeconds.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: Theme.of(context).textTheme.titleMedium,
      decoration: const InputDecoration(
        labelText: 'Duration (seconds)',
        prefixIcon: Icon(Icons.timer_outlined, size: 20),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      onChanged: (value) {
        final seconds = int.tryParse(value);
        if (seconds != null && seconds > 0) widget.onChanged?.call(seconds);
      },
    );
  }
}

// ── Cue Row ───────────────────────────────────────────────────────────────────

/// Displays the [AudioCue] pool as chips and an "Add Sound" icon button.
class _CueRow extends StatelessWidget {
  const _CueRow({required this.cues, this.onAddSound});

  final List<AudioCue> cues;
  final VoidCallback? onAddSound;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: cues.isEmpty
              ? Text('No sounds — tap + to add', style: theme.textTheme.bodySmall)
              : Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: cues
                      .map(
                        (c) => Chip(
                          label: Text(c.name),
                          labelStyle: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.blockAction,
                            fontWeight: FontWeight.bold,
                          ),
                          backgroundColor:
                              AppTheme.blockAction.withValues(alpha: 0.12),
                          side: BorderSide.none,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      )
                      .toList(),
                ),
        ),
        // Add Sound — 48×48 tap target [UI-02]
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              color: AppTheme.blockAction,
              size: 24,
            ),
            onPressed: onAddSound,
            tooltip: 'Add sound',
          ),
        ),
      ],
    );
  }
}
