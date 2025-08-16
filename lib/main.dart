// lib/main.dart
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:myapp/config/app_config.dart';
import 'package:myapp/providers/auth_provider.dart';
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
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          title: 'Routine',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            typography: Typography.material2021(),
            useMaterial3: true,
            useSystemColors: true,
            colorScheme: lightDynamic,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            useSystemColors: true,
            typography: Typography.material2021(),
            colorScheme: darkDynamic,
          ),
          themeMode: ThemeMode.system,
          home: const MainHomeScreen(), // Added const for better performance
        );
      },
    );
  }
}