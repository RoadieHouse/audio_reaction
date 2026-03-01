import 'package:flutter/material.dart';

import '../models/audio_cue.dart';
import '../models/sequence_block.dart';
import '../theme/app_theme.dart';
import '../widgets/blocks/block_cards.dart';
import '../widgets/sound_picker_bottom_sheet.dart';

/// Session builder screen: assemble a sequence of training blocks.
class CreateSessionScreen extends StatelessWidget {
  const CreateSessionScreen({super.key});

  static const routeName = '/create';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Session')),
      body: const _CreateSessionBody(),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _CreateSessionBody extends StatelessWidget {
  const _CreateSessionBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Session Name TextField ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: TextField(
            style: Theme.of(context).textTheme.titleMedium,
            decoration: const InputDecoration(
              labelText: 'Session Name',
              hintText: 'e.g., 5-3-2 Ladder Drill',
              prefixIcon: Icon(Icons.label_outline_rounded),
            ),
          ),
        ),

        // ── Block Timeline ─────────────────────────────────────────────
        const Expanded(child: _BlockTimeline()),

        // ── Bottom Action Row ──────────────────────────────────────────
        _BottomActionRow(),
      ],
    );
  }
}

// ── Block Timeline ────────────────────────────────────────────────────────────

class _BlockTimeline extends StatelessWidget {
  const _BlockTimeline();

  // Prototype sequence — replaced by SessionProvider.draftSession.sequence
  // when the Provider is wired in a future step.
  static final List<SequenceBlock> _demoBlocks = [
    const WarmUpBlock(id: 'b1', duration: Duration(seconds: 60)),
    ActionBlock(
      id: 'b2',
      audioCues: [
        AudioCue(id: 's1', name: 'Beep High', filePath: 'assets/sounds/beep_high.mp3', isCustom: false),
        AudioCue(id: 's2', name: 'Beep Low',  filePath: 'assets/sounds/beep_low.mp3',  isCustom: false),
      ],
    ),
    const DelayBlock(id: 'b3', duration: Duration(seconds: 3)),
    ActionBlock(
      id: 'b4',
      audioCues: [
        AudioCue(id: 'r1', name: 'Voice: Left', filePath: null, isCustom: true),
      ],
    ),
    const DelayBlock(id: 'b5', duration: Duration(seconds: 2)),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: _demoBlocks.length,
      itemBuilder: (context, index) => _BlockRow(
        block: _demoBlocks[index],
        isLast: index == _demoBlocks.length - 1,
      ),
    );
  }
}

// ── Block Row (timeline connector + card dispatch) ────────────────────────────

class _BlockRow extends StatelessWidget {
  const _BlockRow({required this.block, required this.isLast});

  final SequenceBlock block;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(block);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Timeline connector ───────────────────────────────────────────
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(top: 18),
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: accent.withValues(alpha: 0.3)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // ── Card dispatch ────────────────────────────────────────────────
          Expanded(child: _cardFor(context, block)),
        ],
      ),
    );
  }

  Widget _cardFor(BuildContext context, SequenceBlock block) {
    if (block is WarmUpBlock) return WarmUpCard(block: block);
    if (block is DelayBlock)  return DelayCard(block: block);
    if (block is ActionBlock) {
      return ActionCard(
        block: block,
        onAddSound: () => showSoundPickerBottomSheet(
          context,
          onSoundSelected: (_) {}, // wired to Provider in a future step
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Color _accentFor(SequenceBlock block) {
    if (block is WarmUpBlock) return AppTheme.blockWarmUp;
    if (block is DelayBlock)  return AppTheme.blockDelay;
    if (block is ActionBlock) return AppTheme.blockAction;
    return AppTheme.blockDelay;
  }
}

// ── Bottom Action Row ─────────────────────────────────────────────────────────

class _BottomActionRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          // Add Action — opens SoundPickerBottomSheet
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => showSoundPickerBottomSheet(
                context,
                onSoundSelected: (_) {}, // wired to Provider in a future step
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Action'),
            ),
          ),

          const SizedBox(width: 12),

          // Add Delay
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {}, // dummy
              icon: const Icon(Icons.hourglass_empty_rounded),
              label: const Text('Add Delay'),
            ),
          ),
        ],
      ),
    );
  }
}
