import 'package:flutter/material.dart';
import '../data/dummy_data.dart';
import 'active_session_screen.dart';
import 'create_session_screen.dart';

/// Entry screen: shows a list of saved training sessions.
/// Provides access to start (play) a session and create a new one.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const routeName = '/';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sprint React')),
      body: kDummySessions.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: kDummySessions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) =>
                  _SessionTile(session: kDummySessions[index]),
            ),
      floatingActionButton: _CreateSessionFab(),
    );
  }
}

// ── Session Tile ──────────────────────────────────────────────────────────────

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});

  final DummySession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // ── Text content ────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.name,
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
                      Text(session.duration, style: theme.textTheme.bodySmall),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.layers_outlined,
                        size: 14,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${session.blockCount} blocks',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Play Button (64×64 min target) ──────────────────────────────
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 64,
              height: 64,
              child: IconButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  ActiveSessionScreen.routeName,
                  arguments: session,
                ),
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
    );
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
