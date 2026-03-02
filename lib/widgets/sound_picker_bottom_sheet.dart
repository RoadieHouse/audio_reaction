import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../models/audio_cue.dart';
import '../models/sequence_block.dart';
import '../providers/session_provider.dart';
import '../services/audio_service.dart';
import '../services/recording_service.dart';

// ── Module-level helpers ──────────────────────────────────────────────────────

/// Formats [d] as "2.4s" for durations under 60 s, or "1:04" for longer.
String _formatDuration(Duration d) {
  if (d.inSeconds < 60) {
    return '${(d.inMilliseconds / 1000).toStringAsFixed(1)}s';
  }
  return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

/// Shows a dialog with a pre-filled [TextField] for naming a cue.
/// Returns the trimmed name, or null if cancelled / left empty.
Future<String?> _showNameDialog(BuildContext context, String initial) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Name your cue'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'e.g., Left, Right, Go'),
        onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(null),
          child: const Text('Discard'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  // Do NOT dispose the controller here — the dialog exit animation may still
  // be running, which would trigger "TextEditingController used after dispose".
  return (result == null || result.isEmpty) ? null : result;
}

/// Renames the .m4a file at [originalPath] to the sanitised [name].
/// Errors are swallowed so the caller never needs to handle them.
Future<void> _renameRecording(String originalPath, String name) async {
  try {
    final original = File(originalPath);
    final sanitised = name.replaceAll(RegExp(r'[^\w\-]'), '_');
    final dir = original.parent.path;
    await original.rename('$dir/$sanitised.m4a');
  } catch (e) {
    assert(() {
      // ignore: avoid_print
      print('[SoundPicker] rename failed: $e');
      return true;
    }());
  }
}

/// Opens the sound-picker bottom sheet.
///
/// The sheet reads [SessionProvider] from context directly.
/// When [existingBlockId] is null, selecting a cue creates a new [ActionBlock]
/// and appends it to the draft. When [existingBlockId] is provided, the cue is
/// appended to that block's [ActionBlock.audioCues] list instead.
void showSoundPickerBottomSheet(BuildContext context,
    {String? existingBlockId}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SoundPickerSheet(existingBlockId: existingBlockId),
  );
}

// ── Private Sheet Widget ──────────────────────────────────────────────────────

class _SoundPickerSheet extends StatefulWidget {
  const _SoundPickerSheet({this.existingBlockId});

  /// When non-null, the selected cue is added to this block's audioCues list.
  /// When null, a new ActionBlock is created.
  final String? existingBlockId;

  @override
  State<_SoundPickerSheet> createState() => _SoundPickerSheetState();
}

class _SoundPickerSheetState extends State<_SoundPickerSheet> {
  /// Cached audio durations keyed by [AudioCue.id]. Populated lazily.
  final Map<String, Duration> _durationCache = {};

  @override
  void initState() {
    super.initState();
    // Refresh the custom recordings list each time the sheet opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SessionProvider>().loadCustomSounds();
    });
  }

  /// Probes the duration of [cue] using a short-lived [AudioPlayer] and caches
  /// the result. Triggers a rebuild so rows can display the duration.
  Future<void> _probeDuration(AudioCue cue) async {
    if (_durationCache.containsKey(cue.id) || !mounted) return;
    try {
      final player = AudioPlayer();
      try {
        final path = cue.filePath;
        if (path == null || path.isEmpty) return;
        final source = cue.isCustom
            ? AudioSource.uri(Uri.file(path))
            : AudioSource.asset(path);
        final dur = await player.setAudioSource(source);
        if (dur != null && mounted) {
          setState(() => _durationCache[cue.id] = dur);
        }
      } finally {
        await player.dispose();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            _DragHandle(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Text('Select Sound', style: theme.textTheme.titleMedium),
                ],
              ),
            ),

            TabBar(
              tabs: const [
                Tab(text: 'Default Sounds'),
                Tab(text: 'My Recordings'),
              ],
            ),

            Expanded(
              child: Consumer<SessionProvider>(
                builder: (context, provider, _) => TabBarView(
                  children: [
                    _SoundList(
                      cues: provider.availableDefaultSounds,
                      onSelected: (cue) => _onCueSelected(context, cue),
                      durationCache: _durationCache,
                      onProbeNeeded: _probeDuration,
                    ),
                    _RecordingsTab(
                      cues: provider.availableCustomSounds,
                      onSelected: (cue) => _onCueSelected(context, cue),
                      durationCache: _durationCache,
                      onProbeNeeded: _probeDuration,
                    ),
                  ],
                ),
              ),
            ),

            _RecordButton(),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  void _onCueSelected(BuildContext context, AudioCue cue) {
    final provider = context.read<SessionProvider>();
    final existingBlockId = widget.existingBlockId;

    if (existingBlockId == null) {
      // New block mode — create and append a fresh ActionBlock.
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      provider.addBlockToDraft(ActionBlock(id: id, audioCues: [cue]));
    } else {
      // Add-to-existing mode — append the cue to the matching ActionBlock.
      final sequence = provider.draftSession?.sequence ?? const [];
      ActionBlock? target;
      for (final b in sequence) {
        if (b is ActionBlock && b.id == existingBlockId) {
          target = b;
          break;
        }
      }
      if (target != null) {
        provider.updateBlockInDraft(
          target.copyWith(audioCues: [...target.audioCues, cue]),
        );
      }
    }
    Navigator.of(context).pop();
  }
}

// ── Sound List ────────────────────────────────────────────────────────────────

class _SoundList extends StatelessWidget {
  const _SoundList({
    required this.cues,
    required this.onSelected,
    required this.durationCache,
    required this.onProbeNeeded,
  });

  final List<AudioCue> cues;
  final ValueChanged<AudioCue> onSelected;
  final Map<String, Duration> durationCache;
  final Future<void> Function(AudioCue) onProbeNeeded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (cues.isEmpty) {
      return Center(
        child: Text('No sounds available', style: theme.textTheme.bodySmall),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: cues.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (_, index) {
        final cue = cues[index];
        return _CueRow(
          key: ValueKey(cue.id),
          cue: cue,
          onSelected: () => onSelected(cue),
          duration: durationCache[cue.id],
          onProbeNeeded: () => onProbeNeeded(cue),
        );
      },
    );
  }
}

// ── Recordings Tab ────────────────────────────────────────────────────────────

/// My Recordings tab — shows custom .m4a files, or an empty state with a
/// hint to use the record button below when none exist yet.
class _RecordingsTab extends StatelessWidget {
  const _RecordingsTab({
    required this.cues,
    required this.onSelected,
    required this.durationCache,
    required this.onProbeNeeded,
  });

  final List<AudioCue> cues;
  final ValueChanged<AudioCue> onSelected;
  final Map<String, Duration> durationCache;
  final Future<void> Function(AudioCue) onProbeNeeded;

  @override
  Widget build(BuildContext context) {
    if (cues.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mic_none_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 12),
            Text(
              'No recordings yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Hold the button below to record a cue.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }
    return _RecordingsList(
      cues: cues,
      onSelected: onSelected,
      durationCache: durationCache,
      onProbeNeeded: onProbeNeeded,
    );
  }
}

// ── Recordings List (with rename / delete actions) ────────────────────────────

/// Like [_SoundList] but adds Rename and Delete icon buttons to each row.
/// Only used inside the "My Recordings" tab.
class _RecordingsList extends StatelessWidget {
  const _RecordingsList({
    required this.cues,
    required this.onSelected,
    required this.durationCache,
    required this.onProbeNeeded,
  });

  final List<AudioCue> cues;
  final ValueChanged<AudioCue> onSelected;
  final Map<String, Duration> durationCache;
  final Future<void> Function(AudioCue) onProbeNeeded;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: cues.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final cue = cues[index];
        return _CueRow(
          key: ValueKey(cue.id),
          cue: cue,
          onSelected: () => onSelected(cue),
          duration: durationCache[cue.id],
          onProbeNeeded: () => onProbeNeeded(cue),
          trailingActions: [
            // ── Rename ────────────────────────────────────────────────────
            SizedBox(
              width: 36,
              height: 36,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 20,
                icon: const Icon(Icons.drive_file_rename_outline_rounded),
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
                tooltip: 'Rename',
                onPressed: () async {
                  final name = await _showNameDialog(context, cue.name);
                  if (name == null || !context.mounted) return;
                  await _renameRecording(cue.filePath!, name);
                  if (context.mounted) {
                    await context.read<SessionProvider>().loadCustomSounds();
                  }
                },
              ),
            ),
            const SizedBox(width: 4),
            // ── Delete ────────────────────────────────────────────────────
            SizedBox(
              width: 36,
              height: 36,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 20,
                icon: const Icon(Icons.delete_outline_rounded),
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
                tooltip: 'Delete',
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete recording?'),
                      content: Text(
                        'Delete "${cue.name}"? This cannot be undone.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true || !context.mounted) return;
                  try {
                    await File(cue.filePath!).delete();
                  } catch (e) {
                    assert(() {
                      // ignore: avoid_print
                      print('[SoundPicker] delete failed: $e');
                      return true;
                    }());
                  }
                  if (context.mounted) {
                    await context.read<SessionProvider>().loadCustomSounds();
                  }
                },
              ),
            ),
            const SizedBox(width: 4),
          ],
        );
      },
    );
  }
}

// ── Record Button ─────────────────────────────────────────────────────────────

class _RecordButton extends StatefulWidget {
  @override
  State<_RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<_RecordButton>
    with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  String? _pendingFileName;

  /// Drives two staggered pulsing rings during recording.
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  /// Builds one expanding-and-fading ring. [offset] staggers it by 0–1.
  Widget _pulseRing(double offset, Color color) {
    final v = (_pulseCtrl.value + offset) % 1.0;
    return Container(
      width: 56 + 40 * v,
      height: 56 + 40 * v,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.28 * (1.0 - v)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;
    final primaryColor = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Hint text — fades out while recording so the animation has full focus
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _isRecording ? 0.0 : 1.0,
            child: Text('Hold to record', style: theme.textTheme.bodySmall),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onLongPressStart: (_) async {
              final recorder = context.read<RecordingService>();
              final granted = await recorder.requestPermission();
              if (!granted) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Microphone permission denied.')),
                  );
                }
                return;
              }
              // Human-friendly sequential name based on existing recording count
              final count = context
                  .read<SessionProvider>()
                  .availableCustomSounds
                  .length;
              _pendingFileName = 'Cue ${count + 1}';
              await recorder.startRecording(_pendingFileName!);
              if (mounted) {
                setState(() => _isRecording = true);
                _pulseCtrl.repeat();
              }
            },
            onLongPressEnd: (_) async {
              _pulseCtrl
                ..stop()
                ..reset();
              final recorder = context.read<RecordingService>();
              final filePath = await recorder.stopRecording();
              if (mounted) setState(() => _isRecording = false);

              if (filePath == null || !mounted) return;

              final name = await _showNameDialog(
                  context, _pendingFileName ?? 'Cue 1');
              if (name == null || !mounted) return;

              await _renameRecording(filePath, name);

              if (mounted) {
                await context.read<SessionProvider>().loadCustomSounds();
              }
            },
            // 96×96 hit area contains the 56px button + up to 96px of rings
            child: SizedBox(
              width: 96,
              height: 96,
              child: AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, _) => Stack(
                  alignment: Alignment.center,
                  children: [
                    // Two staggered rings — only present while recording
                    if (_isRecording) ...[
                      _pulseRing(0.0, errorColor),
                      _pulseRing(0.5, errorColor),
                    ],
                    // Main circular button
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording
                            ? errorColor
                            : theme.colorScheme.surfaceContainerHighest,
                      ),
                      child: Icon(
                        _isRecording
                            ? Icons.fiber_manual_record_rounded
                            : Icons.mic_rounded,
                        size: 24,
                        color: _isRecording
                            ? theme.colorScheme.onError
                            : primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Cue Row ───────────────────────────────────────────────────────────────────

/// A single sound row. Uses [AudioService] preview streams to:
/// - Highlight its border when this cue is actively previewing.
/// - Toggle the trailing icon between play and stop.
/// - Show a thin progress bar below the row while previewing.
/// - Optionally shows [trailingActions] (e.g. rename/delete for recordings).
class _CueRow extends StatefulWidget {
  const _CueRow({
    super.key,
    required this.cue,
    required this.onSelected,
    this.duration,
    this.onProbeNeeded,
    this.trailingActions,
  });

  final AudioCue cue;
  final VoidCallback onSelected;

  /// Pre-resolved duration from the sheet-level cache. Null while probing.
  final Duration? duration;

  /// Called once (post-frame) when [duration] is null to request a probe.
  final VoidCallback? onProbeNeeded;

  /// Additional widgets placed between the duration label and the play button.
  final List<Widget>? trailingActions;

  @override
  State<_CueRow> createState() => _CueRowState();
}

class _CueRowState extends State<_CueRow> {
  @override
  void initState() {
    super.initState();
    if (widget.duration == null && widget.onProbeNeeded != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onProbeNeeded!();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final audio = context.read<AudioService>();
    final theme = Theme.of(context);

    return StreamBuilder<String?>(
      stream: audio.previewingCueIdStream,
      initialData: audio.currentPreviewingCueId,
      builder: (context, snap) {
        final isActive = snap.data == widget.cue.id;
        return InkWell(
          onTap: widget.onSelected,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? theme.colorScheme.primary.withValues(alpha: 0.5)
                    : theme.colorScheme.outlineVariant,
                width: isActive ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.cue.isCustom
                            ? Icons.mic_rounded
                            : Icons.music_note_rounded,
                        color: isActive
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        size: 24,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          widget.cue.name,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      // Duration label — hidden while probing
                      if (widget.duration != null) ...[
                        Text(
                          _formatDuration(widget.duration!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      // Extra actions (rename / delete for recordings)
                      ...?widget.trailingActions,
                      // Play / stop button
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            isActive
                                ? Icons.stop_circle_outlined
                                : Icons.play_circle_outline_rounded,
                          ),
                          iconSize: 28,
                          color: theme.colorScheme.primary,
                          tooltip: isActive ? 'Stop' : 'Preview',
                          onPressed: isActive
                              ? () => audio.stopPreview()
                              : () => audio.previewCue(widget.cue),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActive) _PreviewProgressBar(audio: audio),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Preview Progress Bar ──────────────────────────────────────────────────────

/// Thin progress bar shown beneath a [_CueRow] while its cue is previewing.
class _PreviewProgressBar extends StatelessWidget {
  const _PreviewProgressBar({required this.audio});

  final AudioService audio;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: audio.previewPositionStream,
      builder: (context, posSnap) => StreamBuilder<Duration?>(
        stream: audio.previewDurationStream,
        builder: (context, durSnap) {
          final pos = posSnap.data ?? Duration.zero;
          final dur = durSnap.data;
          final progress = (dur != null && dur.inMilliseconds > 0)
              ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
              : 0.0;
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: Colors.transparent,
              color: Theme.of(context).colorScheme.primary,
            ),
          );
        },
      ),
    );
  }
}

// ── Drag Handle ───────────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
