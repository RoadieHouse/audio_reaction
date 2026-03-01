import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/audio_cue.dart';
import '../models/sequence_block.dart';
import '../providers/session_provider.dart';
import '../services/audio_service.dart';
import '../services/recording_service.dart';

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
  @override
  void initState() {
    super.initState();
    // Refresh the custom recordings list each time the sheet opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SessionProvider>().loadCustomSounds();
    });
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
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),

            Expanded(
              child: Consumer<SessionProvider>(
                builder: (context, provider, _) => TabBarView(
                  children: [
                    _SoundList(
                      cues: provider.availableDefaultSounds,
                      onSelected: (cue) => _onCueSelected(context, cue),
                    ),
                    _RecordingsTab(
                      cues: provider.availableCustomSounds,
                      onSelected: (cue) => _onCueSelected(context, cue),
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
  const _SoundList({required this.cues, required this.onSelected});

  final List<AudioCue> cues;
  final ValueChanged<AudioCue> onSelected;

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
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, index) {
        final cue = cues[index];
        return InkWell(
          onTap: () => onSelected(cue),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.music_note_rounded,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(cue.name, style: theme.textTheme.titleMedium),
                ),
                // Preview play button
                SizedBox(
                  width: 40,
                  height: 40,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.play_circle_outline_rounded),
                    iconSize: 28,
                    color: theme.colorScheme.primary,
                    onPressed: () =>
                        context.read<AudioService>().previewCue(cue),
                    tooltip: 'Preview',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Recordings Tab ────────────────────────────────────────────────────────────

/// My Recordings tab — shows custom .m4a files, or an empty state with a
/// hint to use the record button below when none exist yet.
class _RecordingsTab extends StatelessWidget {
  const _RecordingsTab({required this.cues, required this.onSelected});

  final List<AudioCue> cues;
  final ValueChanged<AudioCue> onSelected;

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
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
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
    return _SoundList(cues: cues, onSelected: onSelected);
  }
}

// ── Record Button ─────────────────────────────────────────────────────────────

class _RecordButton extends StatefulWidget {
  @override
  State<_RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<_RecordButton> {
  bool _isRecording = false;
  String? _pendingFileName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const recordingColor = Colors.redAccent;
    final idleColor = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Hold to record a custom cue',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
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
              _pendingFileName =
                  'cue_${DateTime.now().millisecondsSinceEpoch}';
              await recorder.startRecording(_pendingFileName!);
              if (mounted) setState(() => _isRecording = true);
            },
            onLongPressEnd: (_) async {
              final recorder = context.read<RecordingService>();
              final filePath = await recorder.stopRecording();
              if (mounted) setState(() => _isRecording = false);

              if (filePath == null || !mounted) return;

              final name = await _showNameDialog(
                  context, _pendingFileName ?? 'New Cue');
              if (name == null || !mounted) return;

              await _renameRecording(filePath, name);

              if (mounted) {
                await context.read<SessionProvider>().loadCustomSounds();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              height: 64,
              decoration: BoxDecoration(
                color: _isRecording
                    ? recordingColor.withValues(alpha: 0.12)
                    : idleColor,
                borderRadius: BorderRadius.circular(16),
                border: _isRecording
                    ? Border.all(color: recordingColor, width: 2)
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedScale(
                    scale: _isRecording ? 1.3 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      _isRecording
                          ? Icons.fiber_manual_record_rounded
                          : Icons.mic_rounded,
                      size: 28,
                      color: _isRecording ? recordingColor : Colors.black,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isRecording ? 'Recording…' : 'Record New Cue',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: _isRecording ? recordingColor : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Shows an AlertDialog with a TextField. Returns the trimmed name the user
  /// entered, or null if they cancelled or left the field empty.
  Future<String?> _showNameDialog(
      BuildContext context, String initial) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Name your cue'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g., Left, Right, Go',
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    // Do NOT call controller.dispose() here — the dialog's exit animation
    // may still be running and the TextField will call addListener on it,
    // causing "TextEditingController used after being disposed" crash.
    return (result == null || result.isEmpty) ? null : result;
  }

  /// Renames the .m4a file on disk to the sanitised user-supplied [name].
  /// If renaming fails the original file is kept and the error is swallowed.
  Future<void> _renameRecording(String originalPath, String name) async {
    try {
      final original = File(originalPath);
      final sanitised = name.replaceAll(RegExp(r'[^\w\-]'), '_');
      final dir = original.parent.path;
      final newPath = '$dir/$sanitised.m4a';
      await original.rename(newPath);
    } catch (e) {
      assert(() {
        // ignore: avoid_print
        print('[RecordButton] rename failed: $e');
        return true;
      }());
    }
  }
}

// ── Drag Handle ───────────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
