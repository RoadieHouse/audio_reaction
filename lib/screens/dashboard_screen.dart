import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/training_session.dart';
import '../providers/session_provider.dart';
import '../services/audio_service.dart';
import 'active_session_screen.dart';
import 'create_session_screen.dart';

/// Entry screen: shows the library of saved training sessions.
/// Provides access to start (play) a session and create a new one.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const routeName = '/';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sprint React')),
      body: Consumer<SessionProvider>(
        builder: (context, provider, _) {
          final sessions = provider.sessions;
          if (sessions.isEmpty) return const _EmptyState();
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: sessions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) =>
                _SessionTile(session: sessions[index]),
          );
        },
      ),
      floatingActionButton: _CreateSessionFab(),
    );
  }
}

// ── Session Tile ──────────────────────────────────────────────────────────────

class _SessionTile extends StatefulWidget {
  const _SessionTile({required this.session});

  final TrainingSession session;

  @override
  State<_SessionTile> createState() => _SessionTileState();
}

class _SessionTileState extends State<_SessionTile> {
  bool _loading = false;

  // FIX 1+2: debounce + call play() after loadSession().
  Future<void> _onPlay(BuildContext context) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final audio = context.read<AudioService>();
      await audio.loadSession(widget.session);
      await audio.play();
    } catch (_) {
      // Errors are logged inside AudioService; navigate anyway.
    }
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.pushNamed(
      context,
      ActiveSessionScreen.routeName,
      arguments: widget.session,
    );
  }

  // FIX 5: tap text area to edit.
  void _onEdit(BuildContext context) {
    context.read<SessionProvider>().editExistingSession(widget.session);
    Navigator.pushNamed(context, CreateSessionScreen.routeName);
  }

  // FIX 5: swipe-to-delete with confirmation.
  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete session?'),
        content: Text(
            'Delete "${widget.session.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent),
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
      key: ValueKey(widget.session.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) =>
          context.read<SessionProvider>().deleteSession(widget.session.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 28),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // ── Text content (tappable → edit) ──────────────────────────
            Expanded(
              child: GestureDetector(
                onTap: () => _onEdit(context),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.session.title,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 14,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDuration(widget.session.totalDuration),
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.layers_outlined,
                            size: 14,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.session.actionCount} actions',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Play Button / Loading Indicator (64×64 tap target) ───────
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 64,
                height: 64,
                child: _loading
                    ? const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    : IconButton(
                        onPressed: () => _onPlay(context),
                        icon: Icon(
                          Icons.play_circle_filled_rounded,
                          color: theme.colorScheme.primary,
                          size: 40,
                        ),
                        tooltip: 'Start Session',
                      ),
              ),
            ),
          ],
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

// ── FAB ───────────────────────────────────────────────────────────────────────

class _CreateSessionFab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () =>
          Navigator.pushNamed(context, CreateSessionScreen.routeName),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_run_rounded,
            size: 72,
            color: theme.colorScheme.primary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text('No sessions yet', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Tap + to create your first sprint session.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
