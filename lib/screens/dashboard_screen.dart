import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/training_session.dart';
import '../providers/session_provider.dart';
import 'active_session_screen.dart';
import 'create_session_screen.dart';

/// Entry screen: shows the library of saved training sessions.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const routeName = '/';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Selector<SessionProvider, List<TrainingSession>>(
        selector: (_, p) => p.sessions,
        shouldRebuild: (prev, next) => !identical(prev, next),
        builder: (context, sessions, _) {
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 100,
                pinned: true,
                backgroundColor: theme.scaffoldBackgroundColor,
                surfaceTintColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                  title: Text(
                    'Training',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  background: ColoredBox(
                    color: theme.scaffoldBackgroundColor,
                  ),
                ),
              ),
              if (sessions.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _SessionCard(session: sessions[index]),
                      ),
                      childCount: sessions.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: _CreateSessionFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ── Session Card ──────────────────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final TrainingSession session;

  void _onPlay(BuildContext context) {
    Navigator.pushNamed(
      context,
      ActiveSessionScreen.routeName,
      arguments: session,
    );
  }

  void _onEdit(BuildContext context) {
    context.read<SessionProvider>().editExistingSession(session);
    Navigator.pushNamed(context, CreateSessionScreen.routeName);
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete session?'),
        content: Text('Delete "${session.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) =>
          context.read<SessionProvider>().deleteSession(session.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: theme.colorScheme.onError,
          size: 32,
        ),
      ),
      child: Card(
        child: InkWell(
          onTap: () => _onEdit(context),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Left: title + metadata pills ──────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          // Duration / Infinite pill
                          if (session.isInfinite)
                            _MetaPill(
                              icon: Icons.all_inclusive_rounded,
                              label: 'Infinite',
                            )
                          else
                            _MetaPill(
                              icon: Icons.timer_outlined,
                              label: _formatDuration(session.totalDuration),
                            ),
                          // Actions pill
                          _MetaPill(
                            icon: Icons.bolt_outlined,
                            label: session.actionCount == 1
                                ? '1 action'
                                : '${session.actionCount} actions',
                          ),
                          // Rounds pill (only for finite multi-round sessions)
                          if (!session.isInfinite && session.repeatCount > 1)
                            _MetaPill(
                              icon: Icons.repeat_rounded,
                              label: '${session.repeatCount} rnds',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // ── Right: play button ─────────────────────────────────────
                GestureDetector(
                  onTap: () => _onPlay(context),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primary,
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 32,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m == 0) return '$s sec';
    if (s == 0) return '$m min';
    return '$m min $s sec';
  }
}

// ── Metadata pill ─────────────────────────────────────────────────────────────

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: muted),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

// ── FAB ───────────────────────────────────────────────────────────────────────

class _CreateSessionFab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
        context.read<SessionProvider>().startNewDraft();
        Navigator.pushNamed(context, CreateSessionScreen.routeName);
      },
      icon: const Icon(Icons.add_rounded),
      label: const Text(
        'New Session',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 80,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 20),
          Text(
            'No sessions yet.',
            style: theme.textTheme.titleMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first reaction training.',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

