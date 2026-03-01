import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/audio_cue.dart';
import '../models/sequence_block.dart';
import '../providers/session_provider.dart';

/// Opens the sound-picker bottom sheet.
///
/// The sheet reads [SessionProvider] from context directly.
/// When the user selects a cue, a new [ActionBlock] is appended to the draft
/// via [SessionProvider.addBlockToDraft] and the sheet closes automatically.
void showSoundPickerBottomSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _SoundPickerSheet(),
  );
}

// ── Private Sheet Widget ──────────────────────────────────────────────────────

class _SoundPickerSheet extends StatefulWidget {
  const _SoundPickerSheet();

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
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    context.read<SessionProvider>().addBlockToDraft(
          ActionBlock(id: id, audioCues: [cue]),
        );
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
                // Preview play button — logic wired in future step
                SizedBox(
                  width: 40,
                  height: 40,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.play_circle_outline_rounded),
                    iconSize: 28,
                    color: theme.colorScheme.primary,
                    onPressed: () {},
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
            onLongPressStart: (_) => setState(() => _isRecording = true),
            onLongPressEnd: (_) => setState(() => _isRecording = false),
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
