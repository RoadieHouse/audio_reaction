import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/active_session_screen.dart';
import 'screens/create_session_screen.dart';
import 'data/dummy_data.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Force portrait orientation for the active session screen
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const SprintReactApp());
}

class SprintReactApp extends StatelessWidget {
  const SprintReactApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sprint React',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: DashboardScreen.routeName,
      routes: {
        DashboardScreen.routeName: (_) => const DashboardScreen(),
        CreateSessionScreen.routeName: (_) => const CreateSessionScreen(),
      },
      // ActiveSessionScreen receives an optional DummySession argument
      onGenerateRoute: (settings) {
        if (settings.name == ActiveSessionScreen.routeName) {
          final session = settings.arguments as DummySession?;
          return MaterialPageRoute(
            builder: (_) => ActiveSessionScreen(session: session),
            settings: settings,
          );
        }
        return null;
      },
    );
  }
}
