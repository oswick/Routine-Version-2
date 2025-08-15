// lib/main.dart - Versión actualizada con WorkManager
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:myapp/config/app_config.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/event_provider.dart';
import 'package:myapp/screens/nav_screen.dart';
import 'package:myapp/services/connectivity_service.dart';
import 'package:myapp/services/local_stogare_service.dart';
import 'package:myapp/services/background_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'utils/notification_service.dart';
import 'utils/app_lifecycle_handler.dart';
import 'package:permission_handler/permission_handler.dart';

// Simplificado - el WorkManager manejará las tareas en segundo plano
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // Paso 1: inicializar WorkManager
  await BackgroundService.initWorkManager();

  // Paso 2: registrar tarea (puede ser aquí o en otro momento)
  await BackgroundService.registerRescheduleTask();

  runApp(const MyApp());
}

Future<void> _requestPermissions() async {
  try {
    // Request all necessary permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.notification,
      Permission.scheduleExactAlarm,
      Permission.ignoreBatteryOptimizations,
    ].request();

    print('Permission statuses: $statuses');

    // Solicitar permisos específicos de Android 12+
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
    
    // Mostrar configuración de batería si es necesario
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
    // Inicializar el lifecycle handler después del primer build
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
    return ChangeNotifierProvider<EventProvider>.value(
      value: EventProvider(),
      child: DynamicColorBuilder(
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
            home: MainHomeScreen(),
          );
        },
      ),
    );
  }
}