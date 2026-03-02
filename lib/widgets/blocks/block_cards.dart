import 'package:flutter/material.dart';

import '../../models/audio_cue.dart';
import '../../models/sequence_block.dart';
import '../../theme/app_theme.dart'; // BlockColors ThemeExtension

// ── WarmUpCard ────────────────────────────────────────────────────────────────

/// Minimalist card for a [WarmUpBlock].
/// The warm-up is non-deletable, so [onDelete] is always null from the screen.
class WarmUpCard extends StatelessWidget {
  const WarmUpCard({
    super.key,
    required this.block,
    this.onDurationChanged,
    this.onDelete,
  });

  final WarmUpBlock block;
  final ValueChanged<int>? onDurationChanged;

  /// Always null for WarmUp — kept in the API for consistency.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final blockColors = Theme.of(context).extension<BlockColors>()!;
    return _BlockCard(
      accentColor: blockColors.warmUp,
      icon: Icons.timer_outlined,
      label: 'Warm-up',
      onDelete: onDelete,
      trailing: _DurationStepper(
        initialSeconds: block.duration.inSeconds,
        onChanged: onDurationChanged,
        min: 1,
      ),
    );
  }
}

// ── DelayCard ─────────────────────────────────────────────────────────────────

/// Minimalist card for a [DelayBlock].
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
    final blockColors = Theme.of(context).extension<BlockColors>()!;
    return _BlockCard(
      accentColor: blockColors.delay,
      icon: Icons.hourglass_empty_rounded,
      label: 'Delay',
      onDelete: onDelete,
      trailing: _DurationStepper(
        initialSeconds: block.duration.inSeconds,
        onChanged: onDurationChanged,
        min: 1,
      ),
    );
  }
}

// ── ActionCard ────────────────────────────────────────────────────────────────

/// Minimalist card for an [ActionBlock].
/// Displays cues as deletable [Chip]s and an "+ Add Sound" action chip.
class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.block,
    this.onAddSound,
    this.onDelete,
    this.onCueRemoved,
  });

  final ActionBlock block;
  final VoidCallback? onAddSound;
  final VoidCallback? onDelete;

  /// Called when the user taps ✕ on a cue chip. The caller guards against
  /// removing the last cue (must have ≥ 1 cue at all times).
  final ValueChanged<AudioCue>? onCueRemoved;

  @override
  Widget build(BuildContext context) {
    final blockColors = Theme.of(context).extension<BlockColors>()!;
    return _BlockCard(
      accentColor: blockColors.action,
      icon: Icons.bolt_rounded,
      label: 'Action',
      onDelete: onDelete,
      // The cue chips and "+ Add Sound" sit below the title row.
      child: _CueWrap(
        cues: block.audioCues,
        onAddSound: onAddSound,
        onCueRemoved: onCueRemoved,
      ),
    );
  }
}

// ── Shared Block Card Shell ───────────────────────────────────────────────────

/// Elevation-free card with rounded corners and a subtle surface tint.
/// Supports an optional [trailing] widget (inline duration field) and an
/// optional [child] widget rendered below the title row (cue chips).
class _BlockCard extends StatelessWidget {
  const _BlockCard({
    required this.accentColor,
    required this.icon,
    required this.label,
    this.onDelete,
    this.trailing,
    this.child,
  });

  final Color accentColor;
  final IconData icon;
  final String label;
  final VoidCallback? onDelete;

  /// Widget placed on the right side of the title row (e.g., duration field).
  final Widget? trailing;

  /// Widget rendered below the title row (e.g., cue chips for ActionCard).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Title row: icon + label + trailing + delete ─────────────────
          Row(
            children: [
              // Block type icon
              Icon(icon, color: accentColor, size: 20),
              const SizedBox(width: 10),
              // Label
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              // Inline trailing (e.g., duration field)
              if (trailing != null) ...[
                const SizedBox(width: 12),
                Expanded(child: trailing!),
              ] else
                const Spacer(),
              // Delete button — 40×40 tap target
              if (onDelete != null)
                SizedBox(
                  width: 40,
                  height: 40,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.35,
                      ),
                    ),
                    onPressed: onDelete,
                    tooltip: 'Remove block',
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                )
              else
                // Keep height consistent when delete is absent (WarmUp)
                const SizedBox(width: 40, height: 40),
            ],
          ),
          // ── Optional child section (cue chips) ──────────────────────────
          if (child != null) ...[const SizedBox(height: 10), child!],
        ],
      ),
    );
  }
}

// ── Duration Stepper ──────────────────────────────────────────────────────────

/// Inline `−` / value / `+` stepper for setting a duration in whole seconds.
///
/// Stateless — the value lives in the model and is passed in as [initialSeconds].
/// The `−` button is disabled at [min], making the floor self-documenting.
class _DurationStepper extends StatelessWidget {
  const _DurationStepper({
    required this.initialSeconds,
    required this.onChanged,
    this.min = 1,
  });

  final int initialSeconds;
  final ValueChanged<int>? onChanged;
  final int min;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final atMin = initialSeconds <= min;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepBtn(
          icon: Icons.remove_rounded,
          onPressed: (atMin || onChanged == null)
              ? null
              : () => onChanged!(initialSeconds - 1),
        ),
        const SizedBox(width: 6),
        Text(
          '$initialSeconds',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 6),
        _StepBtn(
          icon: Icons.add_rounded,
          onPressed: onChanged == null
              ? null
              : () => onChanged!(initialSeconds + 1),
        ),
        const SizedBox(width: 6),
        Text(
          'sec',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

/// Compact 36×36 icon button used inside [_DurationStepper].
class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 20,
        icon: Icon(icon),
        onPressed: onPressed,
        style: IconButton.styleFrom(
          minimumSize: const Size(36, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

// ── Cue Wrap ──────────────────────────────────────────────────────────────────

/// Renders the [AudioCue] pool as deletable chips plus an "+ Add Sound" chip.
class _CueWrap extends StatelessWidget {
  const _CueWrap({required this.cues, this.onAddSound, this.onCueRemoved});

  final List<AudioCue> cues;
  final VoidCallback? onAddSound;

  /// Called when the user taps ✕ on a cue chip. Null = chips non-deletable.
  final ValueChanged<AudioCue>? onCueRemoved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actionColor = Theme.of(context).extension<BlockColors>()!.action;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        // Existing cue chips with delete ✕
        ...cues.map(
          (c) => Chip(
            label: Text(c.name),
            labelStyle: TextStyle(
              fontSize: 12,
              color: actionColor,
              fontWeight: FontWeight.bold,
            ),
            backgroundColor: actionColor.withValues(alpha: 0.10),
            side: BorderSide.none,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onDeleted: onCueRemoved != null ? () => onCueRemoved!(c) : null,
            deleteIconColor: actionColor.withValues(alpha: 0.6),
          ),
        ),
        // "+ Add Sound" action chip
        ActionChip(
          avatar: Icon(
            Icons.add_rounded,
            size: 16,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          label: Text(
            'Add Sound',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          side: BorderSide(color: theme.colorScheme.outline),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          // TODO: Open sound_picker_bottom_sheet.dart
          onPressed: onAddSound,
        ),
      ],
    );
  }
}
