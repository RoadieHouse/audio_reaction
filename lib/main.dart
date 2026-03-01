import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'models/training_session.dart';
import 'providers/session_provider.dart';
import 'services/audio_service.dart';
import 'theme/app_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/active_session_screen.dart';
import 'screens/create_session_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const SprintReactApp());
}

class SprintReactApp extends StatelessWidget {
  const SprintReactApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionProvider>(
          create: (_) => SessionProvider(),
        ),
        Provider<AudioService>(
          // init() is fire-and-forget; all errors are caught and logged
          // internally so a slow audio-session handshake never blocks the UI.
          create: (_) => AudioService()..init(),
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
