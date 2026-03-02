import 'package:flutter/cupertino.dart';
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 3px solid accent strip — primary block-type differentiator
              Container(width: 3, color: accentColor),
              // Card body
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Label row ────────────────────────────────────────
                      Row(
                        children: [
                          Icon(icon, color: accentColor, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            label.toUpperCase(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: accentColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const Spacer(),
                          if (onDelete != null)
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                iconSize: 16,
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.4),
                                ),
                                onPressed: onDelete,
                                tooltip: 'Remove block',
                                style: IconButton.styleFrom(
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            )
                          else
                            // Keep layout stable when no delete (WarmUp)
                            const SizedBox(width: 32, height: 32),
                        ],
                      ),
                      // ── Thin surface divider ─────────────────────────────
                      const SizedBox(height: 10),
                      Container(height: 1, color: AppTheme.bgSurfaceElevated),
                      const SizedBox(height: 12),
                      // ── Content: stepper (WarmUp/Delay) or chips (Action)
                      if (trailing != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [trailing!],
                        ),
                      ?child,
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
    final atMin = initialSeconds <= min;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CircleStepBtn(
          icon: Icons.remove_rounded,
          onPressed: (atMin || onChanged == null)
              ? null
              : () => onChanged!(initialSeconds - 1),
        ),
        const SizedBox(width: 20),
        // Tapping the number opens a scroll-wheel picker
        GestureDetector(
          onTap: onChanged == null ? null : () => _showScrollPicker(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$initialSeconds',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Text(
                'seconds',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        _CircleStepBtn(
          icon: Icons.add_rounded,
          onPressed: onChanged == null
              ? null
              : () => onChanged!(initialSeconds + 1),
        ),
      ],
    );
  }

  void _showScrollPicker(BuildContext context) {
    // Cap the max at a reasonable ceiling; 600 s = 10 min is plenty for warm-ups.
    const int maxSeconds = 600;
    final clampedMin = min.clamp(1, maxSeconds);
    final range = maxSeconds - clampedMin + 1; // total items
    final initialIndex =
        (initialSeconds.clamp(clampedMin, maxSeconds)) - clampedMin;

    final controller = FixedExtentScrollController(initialItem: initialIndex);
    int selectedValue = initialSeconds.clamp(clampedMin, maxSeconds);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Handle ─────────────────────────────────────────────────
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                // ── Header ─────────────────────────────────────────────────
                Text(
                  'Set Duration',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                // ── Wheel ──────────────────────────────────────────────────
                SizedBox(
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Selection highlight band
                      Positioned(
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.bgSurfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.symmetric(horizontal: 40),
                        ),
                      ),
                      // Picker
                      CupertinoPicker(
                        scrollController: controller,
                        itemExtent: 44,
                        diameterRatio: 1.4,
                        squeeze: 1.0,
                        selectionOverlay: const SizedBox.shrink(),
                        onSelectedItemChanged: (i) {
                          selectedValue = i + clampedMin;
                        },
                        children: List.generate(range, (i) {
                          final secs = i + clampedMin;
                          return Center(
                            child: Text(
                              '$secs',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                                fontFamily: 'Inter',
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // ── Confirm button ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.brandAccent,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 52),
                      shape: const StadiumBorder(),
                      elevation: 0,
                    ),
                    onPressed: () {
                      onChanged!(selectedValue);
                      Navigator.of(ctx).pop();
                    },
                    child: const Text(
                      'Confirm',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Compact circular step button (30×30) used inside [_DurationStepper].
class _CircleStepBtn extends StatelessWidget {
  const _CircleStepBtn({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: AppTheme.bgSurfaceElevated,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(
            icon,
            size: 16,
            color: enabled
                ? AppTheme.textPrimary
                : AppTheme.textSecondary.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}

// ── Cue Wrap ──────────────────────────────────────────────────────────────────

/// Two-column layout:
/// Left  — cue chips stacked vertically.
/// Right — vertically-centered "+" add button.
class _CueWrap extends StatelessWidget {
  const _CueWrap({required this.cues, this.onAddSound, this.onCueRemoved});

  final List<AudioCue> cues;
  final VoidCallback? onAddSound;

  /// Called when the user taps ✕ on a cue chip. Null = chips non-deletable.
  final ValueChanged<AudioCue>? onCueRemoved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Left column: stacked cue chips ──────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < cues.length; i++) ...[
                Chip(
                  label: Text(cues[i].name),
                  labelStyle: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 0,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onDeleted: onCueRemoved != null
                      ? () => onCueRemoved!(cues[i])
                      : null,
                  deleteIcon: const Icon(Icons.close_rounded, size: 14),
                  deleteIconColor: theme.colorScheme.onSurfaceVariant,
                ),
                if (i < cues.length - 1) const SizedBox(height: 6),
              ],
            ],
          ),
        ),

        // ── Right column: fixed 56px width, button centered within it ───
        SizedBox(
          width: 56,
          child: Center(child: _AddCueButton(onTap: onAddSound)),
        ),
      ],
    );
  }
}

/// Small circular "+" button for adding a cue to an action block.
class _AddCueButton extends StatelessWidget {
  const _AddCueButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.bgSurfaceElevated,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Icon(
              Icons.add_rounded,
              size: 18,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
