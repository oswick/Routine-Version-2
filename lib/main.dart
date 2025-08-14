// lib/main.dart - Versión actualizada
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:myapp/config/app_config.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/event_provider.dart';
import 'package:myapp/screens/nav_screen.dart';
import 'package:myapp/services/connectivity_service.dart';
import 'package:myapp/services/local_stogare_service.dart';
import 'package:myapp/services/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'utils/notification_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

@pragma('vm:entry-point')
void alarmCallback() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Supabase en este isolate
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  try {
    print('Alarm triggered at ${DateTime.now()}');

    // Inicializar el servicio de notificaciones
    await NotificationService().init();

    // Verificar y reprogramar notificaciones si es necesario
    await NotificationService().ensureScheduledNotificationsExist();

    // Inicializar el servicio de conectividad
    final connectivityService = ConnectivityService();
    await connectivityService.initialize();

    // Si está en línea, intentar sincronizar en segundo plano
    if (connectivityService.isConnected) {
      final syncService = SyncService();
      await syncService.init();
      await syncService.syncWithServer();
      print('Background sync completed');
    }
  } catch (e) {
    print('Error in alarm callback: $e');
  }
}

// En el método main, asegúrate de que los servicios estén completamente inicializados antes de correr la app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  // Inicialización de servicios en paralelo para optimizar el tiempo de carga
  await Future.wait([
    LocalStorageService().init(),
    ConnectivityService().initialize(),
    EventProvider().init(),
  ]);

  // Inicializar servicios de notificaciones y permisos
  await NotificationService().init();
  await _requestPermissions();

  // Configurar AlarmManager para sincronización en segundo plano
  final bool alarmInitialized = await AndroidAlarmManager.initialize();
  print('Alarm Manager initialized: $alarmInitialized');
  if (alarmInitialized) {
    const int helloAlarmID = 0;
    final bool alarmSet = await AndroidAlarmManager.periodic(
      const Duration(minutes: 5),
      helloAlarmID,
      alarmCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );
    print('Alarm set: $alarmSet');
  }

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
  } catch (e) {
    print('Error requesting permissions: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
