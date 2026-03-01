import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'models/training_session.dart';
import 'providers/session_provider.dart';
import 'services/audio_service.dart';
import 'services/recording_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/active_session_screen.dart';
import 'screens/create_session_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final storage = StorageService();
  final initialSessions = await storage.loadSessions();

  runApp(SprintReactApp(storage: storage, initialSessions: initialSessions));
}

class SprintReactApp extends StatelessWidget {
  const SprintReactApp({
    super.key,
    required this.storage,
    required this.initialSessions,
  });

  final StorageService storage;
  final List<TrainingSession> initialSessions;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionProvider>(
          create: (_) => SessionProvider(
            storage: storage,
            initialSessions: initialSessions,
          ),
        ),
        Provider<AudioService>(
          // init() is fire-and-forget; all errors are caught and logged
          // internally so a slow audio-session handshake never blocks the UI.
          create: (_) => AudioService()..init(),
          dispose: (_, svc) => svc.dispose(),
        ),
        Provider<RecordingService>(
          create: (_) => RecordingService(),
          dispose: (_, svc) => svc.dispose(),
        ),
      ],
      child: MaterialApp(
        title: 'Sprint React',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        initialRoute: DashboardScreen.routeName,
        routes: {
          DashboardScreen.routeName: (_) => const DashboardScreen(),
          CreateSessionScreen.routeName: (_) => const CreateSessionScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == ActiveSessionScreen.routeName) {
            final session = settings.arguments as TrainingSession?;
            return MaterialPageRoute(
              builder: (_) => ActiveSessionScreen(session: session),
              settings: settings,
            );
          }
          return null;
        },
      ),
    );
  }
}
