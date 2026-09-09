import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:myapp/config/app_config.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/providers/auth_provider.dart';
import 'package:myapp/providers/theme_provider.dart';
import 'package:myapp/screens/nav_screen.dart';
import 'package:myapp/screens/onboarding_screen.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/event_provider.dart';
import 'package:myapp/services/connectivity_service.dart';
import 'package:myapp/services/local_stogare_service.dart';
import 'package:myapp/services/background_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'utils/notification_service.dart';
import 'utils/app_lifecycle_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// CRÍTICO: re-exportar el background handler aquí para que el linker de Dart
// lo incluya en el build. Sin este import el compilador puede eliminarlo.
// La función está definida en notification_service.dart como top-level.
// ignore: unused_import
export 'utils/notification_service.dart' show notificationBackgroundHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackgroundService.initWorkManager();
  await BackgroundService.registerRescheduleTask();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  await Future.wait([
    LocalStorageService().init(),
    ConnectivityService().initialize(),
    EventProvider().init(),
  ]);
  await NotificationService().init();

  final themeProvider = ThemeProvider();
  await themeProvider.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => EventProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider.value(value: themeProvider),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLifecycleHandler.instance.initialize(context);
    });
  }

  @override
  void dispose() {
    AppLifecycleHandler.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return M3EMaterialApp(
      title: 'Routine',
      debugShowCheckedModeBanner: false,
      drawUnderSystemBars: true,
      data: themeProvider.themeData,
      autoTheming: true,
      // A user-selected seed is the source of truth for the app accent.
      // Device dynamic color would otherwise replace it on supported devices.
      dynamicColoring: false,
      localizationsDelegates: [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: const [Locale('en'), Locale('es')],
      home: const _StartupGate(),
    );
  }
}

class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  bool? _onboardingCompleted;

  @override
  void initState() {
    super.initState();
    _loadOnboardingState();
  }

  Future<void> _loadOnboardingState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingCompleted == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return _onboardingCompleted!
        ? const MainHomeScreen()
        : const OnboardingScreen();
  }
}
