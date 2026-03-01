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

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});

  final TrainingSession session;

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
                    session.title,
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
                        _formatDuration(session.totalDuration),
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
                        '${session.actionCount} actions',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Play Button (64×64 tap target) ──────────────────────────────
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 64,
              height: 64,
              child: IconButton(
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
    );
  }

  /// Loads the session into the audio engine then navigates to the active
  /// session screen. Navigation proceeds even if [AudioService.loadSession]
  /// throws, so the active screen can handle the error state gracefully.
  Future<void> _onPlay(BuildContext context) async {
    try {
      await context.read<AudioService>().loadSession(session);
    } catch (_) {
      // loadSession errors are logged inside AudioService; we still navigate.
    }
    if (context.mounted) {
      Navigator.pushNamed(
        context,
        ActiveSessionScreen.routeName,
        arguments: session,
      );
    }
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
