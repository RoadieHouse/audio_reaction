import 'package:flutter/material.dart';
import '../data/dummy_data.dart';

/// A reusable modal bottom sheet for picking or recording audio cues.
///
/// Usage:
/// ```dart
/// showSoundPickerBottomSheet(context, onSoundSelected: (sound) { ... });
/// ```
void showSoundPickerBottomSheet(
  BuildContext context, {
  required ValueChanged<DummySound> onSoundSelected,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SoundPickerSheet(onSoundSelected: onSoundSelected),
  );
}

// ── Private Sheet Widget ──────────────────────────────────────────────────────

class _SoundPickerSheet extends StatelessWidget {
  const _SoundPickerSheet({required this.onSoundSelected});

  final ValueChanged<DummySound> onSoundSelected;

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
            // ── Drag Handle ───────────────────────────────────────────────
            _DragHandle(),

            // ── Title Row ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Text('Select Sound', style: theme.textTheme.titleMedium),
                ],
              ),
            ),

            // ── Tab Bar ───────────────────────────────────────────────────
            TabBar(
              tabs: const [
                Tab(text: 'Default Sounds'),
                Tab(text: 'My Recordings'),
              ],
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),

            // ── Tab Views ─────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                children: [
                  _SoundList(
                    sounds: kDefaultSounds,
                    onSelected: onSoundSelected,
                  ),
                  _SoundList(
                    sounds: kMyRecordings,
                    onSelected: onSoundSelected,
                  ),
                ],
              ),
            ),

            // ── Record Button ─────────────────────────────────────────────
            _RecordButton(),

            // Bottom safe area padding
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }
}

// ── Sound List ────────────────────────────────────────────────────────────────

class _SoundList extends StatelessWidget {
  const _SoundList({required this.sounds, required this.onSelected});

  final List<DummySound> sounds;
  final ValueChanged<DummySound> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: sounds.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, index) {
        final sound = sounds[index];
        return InkWell(
          onTap: () {
            onSelected(sound);
            Navigator.of(context).pop();
          },
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
                  child: Text(sound.name, style: theme.textTheme.titleMedium),
                ),
                Text(sound.duration, style: theme.textTheme.bodySmall),
                const SizedBox(width: 12),
                // Preview play button
                SizedBox(
                  width: 40,
                  height: 40,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.play_circle_outline_rounded),
                    iconSize: 28,
                    color: theme.colorScheme.primary,
                    onPressed: () {}, // dummy
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
          // Hint text
          Text(
            'Hold to record a custom cue',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          // Hold-to-record button
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
