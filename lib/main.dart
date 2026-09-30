import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/providers/session_results_provider.dart';
import 'core/providers/stats_provider.dart';
import 'core/providers/user_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase / notifications must never block first paint (white/blank web screen).
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, st) {
    debugPrint('Firebase init failed: $e\n$st');
  }

  if (!kIsWeb) {
    try {
      await NotificationService.instance.initialize();
    } catch (e, st) {
      debugPrint('Notification init failed: $e\n$st');
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()..tryRestoreSession()),
        ChangeNotifierProvider(create: (_) => StatsProvider()),
        // SessionResultsProvider is created per-results-screen via ChangeNotifierProvider.value
        // but we expose one top-level instance for convenience
        ChangeNotifierProvider(create: (_) => SessionResultsProvider()),
      ],
      child: const PitchCoachApp(),
    ),
  );
}

class PitchCoachApp extends StatelessWidget {
  const PitchCoachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pitch Coach',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: context.watch<UserProvider>().themeMode,
      routerConfig: AppRouter.router,
    );
  }
}
