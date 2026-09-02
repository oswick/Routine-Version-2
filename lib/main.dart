// lib/main.dart
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:myapp/config/app_config.dart';
import 'package:myapp/config/app_theme.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/providers/auth_provider.dart';
import 'package:myapp/providers/theme_provider.dart';
import 'package:myapp/screens/nav_screen.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/event_provider.dart';
import 'package:myapp/services/connectivity_service.dart';
import 'package:myapp/services/local_stogare_service.dart';
import 'package:myapp/services/background_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'utils/notification_service.dart';
import 'utils/app_lifecycle_handler.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

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
  await _requestPermissions();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => EventProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

Future<void> _requestPermissions() async {
  try {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.notification,
      Permission.scheduleExactAlarm,
      Permission.ignoreBatteryOptimizations,
    ].request();
    print('Permission statuses: $statuses');

    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }

    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  } catch (e) {
    print('Error requesting permissions: $e');
  }
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
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return DynamicColorBuilder(
          builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
            final lightScheme = themeProvider.useDynamicColor
                ? lightDynamic
                : null;
            final darkScheme = themeProvider.useDynamicColor
                ? darkDynamic
                : null;

            return MaterialApp(
              title: 'Routine',
              debugShowCheckedModeBanner: false,
              localizationsDelegates: const [/* igual */],
              supportedLocales: const [/* igual */],
              theme: AppTheme.lightTheme(
                dynamicColorScheme: lightScheme,
                seedColor: themeProvider.currentSeedColor,
              ),
              darkTheme: AppTheme.darkTheme(
                dynamicColorScheme: darkScheme,
                seedColor: themeProvider.currentSeedColor,
                isAmoled: themeProvider.isAmoled,
              ),
              themeMode: themeProvider.themeMode,
              home: M3ETheme(
                data: themeProvider.themeMode == ThemeMode.dark
                    ? M3EThemeData.dark(
                        seedColor: themeProvider.currentSeedColor,
                      )
                    : M3EThemeData.light(
                        seedColor: themeProvider.currentSeedColor,
                      ),
                child: const MainHomeScreen(),
              ),
            );
          },
        );
      },
    );
  }
}
