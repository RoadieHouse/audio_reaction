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
      if (!mounted) return;
      final provider = context.read<SessionProvider>();
      if (provider.hasDraft) {
        // Editing an existing session — pre-fill the title, do NOT reset draft.
        _titleController.text = provider.draftSession?.title ?? '';
      } else {
        provider.startNewDraft();
      }
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

        // ── Loop Controls ──────────────────────────────────────────────
        const _LoopControlsRow(),

        // ── Block Timeline ─────────────────────────────────────────────
        Expanded(
          child: _BlockTimeline(
            blocks: context.select<SessionProvider, List<SequenceBlock>>(
              (p) => p.draftSession?.sequence ?? const [],
            ),
          ),
        ),

        // ── Bottom Action Row ──────────────────────────────────────────
        _BottomActionRow(),
      ],
    );
  }
}

// ── Block Timeline ────────────────────────────────────────────────────────────

class _BlockTimeline extends StatefulWidget {
  const _BlockTimeline({required this.blocks});

  final List<SequenceBlock> blocks;

  @override
  State<_BlockTimeline> createState() => _BlockTimelineState();
}

class _BlockTimelineState extends State<_BlockTimeline> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(_BlockTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Scroll to the newly added block after it has been laid out.
    if (widget.blocks.length > oldWidget.blocks.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.blocks.isEmpty) {
      return const Center(
        child: Text(
          "Tap 'Add Action' or 'Add Delay' to build your session.",
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: widget.blocks.length,
      itemBuilder: (context, index) => _BlockRow(
        key: ValueKey(widget.blocks[index].id),
        block: widget.blocks[index],
        isLast: index == widget.blocks.length - 1,
      ),
    );
  }
}

// ── Block Row (timeline connector + card dispatch) ────────────────────────────

class _BlockRow extends StatelessWidget {
  const _BlockRow({super.key, required this.block, required this.isLast});

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
    void onDelete() =>
        context.read<SessionProvider>().removeBlockFromDraft(block.id);
    if (block is WarmUpBlock) {
      return WarmUpCard(
        block: block,
        onDelete: null, // warm-up is non-deletable — always present
        onDurationChanged: (secs) => context
            .read<SessionProvider>()
            .updateBlockInDraft(block.copyWith(duration: Duration(seconds: secs))),
      );
    }
    if (block is DelayBlock) {
      return DelayCard(
        block: block,
        onDelete: onDelete,
        onDurationChanged: (secs) => context
            .read<SessionProvider>()
            .updateBlockInDraft(block.copyWith(duration: Duration(seconds: secs))),
      );
    }
    if (block is ActionBlock) {
      return ActionCard(
        block: block,
        onAddSound: () =>
            showSoundPickerBottomSheet(context, existingBlockId: block.id),
        onDelete: onDelete,
        onCueRemoved: (cue) {
          if (block.audioCues.length <= 1) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'An action block must have at least one sound.'),
              ),
            );
            return;
          }
          context.read<SessionProvider>().updateBlockInDraft(
                block.copyWith(
                  audioCues: block.audioCues
                      .where((c) => c.id != cue.id)
                      .toList(),
                ),
              );
        },
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

// ── Loop Controls Row ─────────────────────────────────────────────────────────

class _LoopControlsRow extends StatelessWidget {
  const _LoopControlsRow();

  @override
  Widget build(BuildContext context) {
    final isInfinite = context.select<SessionProvider, bool>(
      (p) => p.draftSession?.isInfinite ?? false,
    );
    final repeatCount = context.select<SessionProvider, int>(
      (p) => p.draftSession?.repeatCount ?? 1,
    );
    final theme = Theme.of(context);
    final dimColor = theme.colorScheme.onSurface.withValues(alpha: 0.4);

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Section header ────────────────────────────────────────────
              Row(
                children: [
                  Icon(Icons.loop_rounded, size: 16, color: dimColor),
                  const SizedBox(width: 6),
                  Text(
                    'Loop Sequence',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: dimColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // ── Controls row ──────────────────────────────────────────────
              Row(
                children: [
                  // Infinite toggle
                  Text('∞  Infinite',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isInfinite
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      )),
                  Switch(
                    value: isInfinite,
                    onChanged: (v) =>
                        context.read<SessionProvider>().updateDraftIsInfinite(v),
                  ),
                  const Spacer(),
                  // Round count stepper (disabled when infinite)
                  Text(
                    'Rounds',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isInfinite ? theme.disabledColor : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.remove_rounded, size: 20),
                      onPressed: isInfinite
                          ? null
                          : () => context
                              .read<SessionProvider>()
                              .updateDraftRepeatCount(repeatCount - 1),
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '$repeatCount',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isInfinite
                            ? theme.disabledColor
                            : theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.add_rounded, size: 20),
                      onPressed: isInfinite
                          ? null
                          : () => context
                              .read<SessionProvider>()
                              .updateDraftRepeatCount(repeatCount + 1),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
  }
}
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
