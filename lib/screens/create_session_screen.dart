import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sequence_block.dart';
import '../providers/session_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/blocks/block_cards.dart';
import '../widgets/sound_picker_bottom_sheet.dart';

/// Session builder screen: assemble a sequence of training blocks.
class CreateSessionScreen extends StatelessWidget {
  const CreateSessionScreen({super.key});

  static const routeName = '/create';

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, _) {
        if (didPop) context.read<SessionProvider>().discardDraft();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create Session'),
          actions: [
            TextButton(
              onPressed: () {
                final saved = context.read<SessionProvider>().saveDraft();
                if (saved) {
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please enter a session name.')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
        body: const _CreateSessionBody(),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _CreateSessionBody extends StatefulWidget {
  const _CreateSessionBody();

  @override
  State<_CreateSessionBody> createState() => _CreateSessionBodyState();
}

class _CreateSessionBodyState extends State<_CreateSessionBody> {
  late final TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SessionProvider>().startNewDraft();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Session Name TextField ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: TextField(
            controller: _titleController,
            onChanged: (v) =>
                context.read<SessionProvider>().updateDraftTitle(v),
            style: Theme.of(context).textTheme.titleMedium,
            decoration: const InputDecoration(
              labelText: 'Session Name',
              hintText: 'e.g., 5-3-2 Ladder Drill',
              prefixIcon: Icon(Icons.label_outline_rounded),
            ),
          ),
        ),

        // ── Block Timeline ─────────────────────────────────────────────
        Expanded(
          child: _BlockTimeline(
            blocks: context.watch<SessionProvider>().draftSession?.sequence ??
                const [],
          ),
        ),

        // ── Bottom Action Row ──────────────────────────────────────────
        _BottomActionRow(),
      ],
    );
  }
}

// ── Block Timeline ────────────────────────────────────────────────────────────

class _BlockTimeline extends StatelessWidget {
  const _BlockTimeline({required this.blocks});

  final List<SequenceBlock> blocks;

  @override
  Widget build(BuildContext context) {
    if (blocks.isEmpty) {
      return const Center(
        child: Text(
          "Tap 'Add Action' or 'Add Delay' to build your session.",
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: blocks.length,
      itemBuilder: (context, index) => _BlockRow(
        block: blocks[index],
        isLast: index == blocks.length - 1,
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
        onAddSound: () => showSoundPickerBottomSheet(context),
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
              onPressed: () => showSoundPickerBottomSheet(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Action'),
            ),
          ),

          const SizedBox(width: 12),

          // Add Delay
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                context.read<SessionProvider>().addBlockToDraft(
                      DelayBlock(
                        id: DateTime.now().microsecondsSinceEpoch.toString(),
                        duration: const Duration(seconds: 3),
                      ),
                    );
              },
              icon: const Icon(Icons.hourglass_empty_rounded),
              label: const Text('Add Delay'),
            ),
          ),
        ],
      ),
    );
  }
}
