import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sequence_block.dart';
import '../providers/session_provider.dart';
import '../theme/app_theme.dart'; // BlockColors ThemeExtension
import '../widgets/blocks/block_cards.dart';
import '../widgets/sound_picker_bottom_sheet.dart';

/// Session builder screen: assemble a sequence of training blocks.
class CreateSessionScreen extends StatefulWidget {
  const CreateSessionScreen({super.key});

  static const routeName = '/create';

  @override
  State<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends State<CreateSessionScreen> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, _) {
        if (didPop && !_saving) context.read<SessionProvider>().discardDraft();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create Session'),
          actions: [
            TextButton(
              onPressed: () {
                final provider = context.read<SessionProvider>();
                if (provider.draftSession?.title.trim().isEmpty ?? true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a session name.'),
                    ),
                  );
                  return;
                }
                // Set saving flag BEFORE saveDraft() so the body widget
                // renders a blank container instead of the empty-draft
                // state during the exit animation — eliminates the flash.
                setState(() => _saving = true);
                provider.saveDraft();
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
        body: _CreateSessionBody(saving: _saving),
        // Large, premium circular FAB
        floatingActionButton: _saving
            ? null
            : SizedBox(
                height: 64, // Explicitly larger than the default 56px FAB
                width: 64,
                child: FloatingActionButton(
                  onPressed: () => _showAddBlockSheet(context),
                  elevation: 0, // Keeps the modern, flat aesthetic
                  highlightElevation: 0,
                  shape:
                      const CircleBorder(), // Forces a perfect circle, overriding any theme defaults
                  child: const Icon(
                    Icons.add_rounded,
                    size:
                        36, // Scaled up icon to perfectly balance the 64px circle
                  ),
                ),
              ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }
}

/// Shows a bottom sheet letting the user choose which type of block to add.
void _showAddBlockSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddBlockSheet(parentContext: context),
  );
}

// ── Add Block Bottom Sheet ────────────────────────────────────────────────────

class _AddBlockSheet extends StatelessWidget {
  const _AddBlockSheet({required this.parentContext});

  /// The navigator context of the screen (not the sheet's own context) so
  /// sound picker and provider calls target the correct route.
  final BuildContext parentContext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blockColors = theme.extension<BlockColors>()!;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Add Block',
            style: theme.textTheme.titleMedium?.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 16),
          // Action block option
          _AddBlockOption(
            icon: Icons.bolt_rounded,
            color: blockColors.action,
            label: 'Action',
            subtitle: 'Plays an audio cue — pick sounds next',
            onTap: () {
              Navigator.pop(context);
              // Opens the sound picker which creates a new ActionBlock.
              showSoundPickerBottomSheet(parentContext);
            },
          ),
          const SizedBox(height: 10),
          // Delay block option
          _AddBlockOption(
            icon: Icons.hourglass_empty_rounded,
            color: blockColors.delay,
            label: 'Delay',
            subtitle: 'A timed rest gap between actions',
            onTap: () {
              Navigator.pop(context);
              parentContext.read<SessionProvider>().addBlockToDraft(
                DelayBlock(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  duration: const Duration(seconds: 3),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AddBlockOption extends StatelessWidget {
  const _AddBlockOption({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _CreateSessionBody extends StatefulWidget {
  const _CreateSessionBody({this.saving = false});

  /// When true the body renders a blank container so that the exit animation
  /// does not flash an empty-draft state after Save is tapped.
  final bool saving;

  @override
  State<_CreateSessionBody> createState() => _CreateSessionBodyState();
}

class _CreateSessionBodyState extends State<_CreateSessionBody> {
  late final TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<SessionProvider>();
    if (provider.hasDraft) {
      // Editing an existing session — pre-fill the title from the draft.
      // Do NOT call startNewDraft(); the draft was set by editExistingSession().
      _titleController = TextEditingController(
        text: provider.draftSession?.title ?? '',
      );
    } else {
      // New session flow — create a blank draft and an empty title controller.
      _titleController = TextEditingController();
      provider.startNewDraft();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Render blank during save/exit so no empty-state flash appears.
    if (widget.saving) {
      return Container(color: Theme.of(context).scaffoldBackgroundColor);
    }

    final blocks = context.select<SessionProvider, List<SequenceBlock>>(
      (p) => p.draftSession?.sequence ?? const [],
    );

    return _BlockTimeline(titleController: _titleController, blocks: blocks);
  }
}

// ── Block Timeline ────────────────────────────────────────────────────────────

/// Renders the full scrollable session editor: title header, loop controls,
/// and the block list — all in a single [CustomScrollView] so the header
/// scrolls naturally with content.
class _BlockTimeline extends StatefulWidget {
  const _BlockTimeline({required this.titleController, required this.blocks});

  final TextEditingController titleController;
  final List<SequenceBlock> blocks;

  @override
  State<_BlockTimeline> createState() => _BlockTimelineState();
}

class _BlockTimelineState extends State<_BlockTimeline> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(_BlockTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-scroll to the newly added block after it is laid out.
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
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // ── Header: title + loop controls ──────────────────────────────
        SliverToBoxAdapter(
          child: _SessionHeader(titleController: widget.titleController),
        ),

        // ── Block list or empty-state ───────────────────────────────────
        if (widget.blocks.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyTimelineState(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
            sliver: SliverList.builder(
              itemCount: widget.blocks.length,
              itemBuilder: (context, index) => _BlockRow(
                key: ValueKey(widget.blocks[index].id),
                block: widget.blocks[index],
                isLast: index == widget.blocks.length - 1,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Session Header (title + loop controls) ────────────────────────────────────

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({required this.titleController});

  final TextEditingController titleController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Large borderless title input acting as the page header.
          TextField(
            controller: titleController,
            onChanged: (v) =>
                context.read<SessionProvider>().updateDraftTitle(v),
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 0,
            ),
            // Explicitly override the global theme for this specific input
            decoration: const InputDecoration(
              hintText: 'Enter Session Name…',
              filled: false, // Removes the grey background fill
              border: InputBorder.none, // Removes default borders
              enabledBorder:
                  InputBorder.none, // Ensures no border when inactive
              focusedBorder:
                  InputBorder.none, // STOPS the brandAccent focus border!
              contentPadding:
                  EdgeInsets.zero, // Keeps it perfectly aligned to the left
              isDense: true, // Makes the input field wrap the text tightly
            ),
            textCapitalization: TextCapitalization.words,
          ),

          const SizedBox(height: 28),

          // Divider between title and loop settings
          const Divider(height: 1),

          const SizedBox(height: 16),

          // Loop settings row
          const _LoopControlsRow(),

          const SizedBox(height: 16),

          const Divider(height: 1),

          const SizedBox(height: 8),
        ],
      ),
    );
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
    final dimColor = theme.colorScheme.onSurface.withValues(alpha: 0.5);

    return Row(
      children: [
        // ── Rounds stepper ─────────────────────────────────────────────
        Text(
          'Rounds',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isInfinite ? theme.disabledColor : dimColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        _StepperButton(
          icon: Icons.remove_rounded,
          onPressed: (isInfinite || repeatCount <= 1)
              ? null
              : () => context.read<SessionProvider>().updateDraftRepeatCount(
                  repeatCount - 1,
                ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 28,
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
        const SizedBox(width: 4),
        _StepperButton(
          icon: Icons.add_rounded,
          onPressed: isInfinite
              ? null
              : () => context.read<SessionProvider>().updateDraftRepeatCount(
                  repeatCount + 1,
                ),
        ),

        const Spacer(),

        // ── Infinite toggle ─────────────────────────────────────────────
        Text(
          '∞  Infinite',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isInfinite ? theme.colorScheme.primary : dimColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 4),
        Switch(
          value: isInfinite,
          onChanged: (v) =>
              context.read<SessionProvider>().updateDraftIsInfinite(v),
        ),
      ],
    );
  }
}

/// Compact icon-only stepper button with a 36×36 tap target.
class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, this.onPressed});

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

// ── Block Row (timeline connector + card dispatch) ────────────────────────────

class _BlockRow extends StatelessWidget {
  const _BlockRow({super.key, required this.block, required this.isLast});

  final SequenceBlock block;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(context, block);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Thin timeline rail (left 24 px) ─────────────────────────────
          SizedBox(
            width: 24,
            child: Column(
              children: [
                // Dot
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 20),
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                // Connector line to next block
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 1.5,
                        color: accent.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // ── Card (right portion) ─────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _cardFor(context, block),
            ),
          ),
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
        onDurationChanged: (secs) =>
            context.read<SessionProvider>().updateBlockInDraft(
              block.copyWith(duration: Duration(seconds: secs)),
            ),
      );
    }
    if (block is DelayBlock) {
      return DelayCard(
        block: block,
        onDelete: onDelete,
        onDurationChanged: (secs) =>
            context.read<SessionProvider>().updateBlockInDraft(
              block.copyWith(duration: Duration(seconds: secs)),
            ),
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
                content: Text('An action block must have at least one sound.'),
              ),
            );
            return;
          }
          context.read<SessionProvider>().updateBlockInDraft(
            block.copyWith(
              audioCues: block.audioCues.where((c) => c.id != cue.id).toList(),
            ),
          );
        },
      );
    }
    return const SizedBox.shrink();
  }

  Color _accentFor(BuildContext context, SequenceBlock block) {
    final blockColors = Theme.of(context).extension<BlockColors>()!;
    if (block is WarmUpBlock) return blockColors.warmUp;
    if (block is DelayBlock) return blockColors.delay;
    if (block is ActionBlock) return blockColors.action;
    return blockColors.delay;
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyTimelineState extends StatelessWidget {
  const _EmptyTimelineState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.queue_music_rounded,
            size: 56,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 16),
          Text(
            'No blocks yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap  + Add Block  to start building.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
