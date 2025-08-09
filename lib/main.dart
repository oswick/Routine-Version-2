// lib/main.dart - Versión actualizada
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
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

// This function will be called periodically by the alarm manager
@pragma('vm:entry-point')
void alarmCallback() async {
  try {
    print('Alarm triggered at ${DateTime.now()}');
    
    // Initialize notification service
    await NotificationService().init();
    
    // Check and reschedule notifications if needed
    await NotificationService().ensureScheduledNotificationsExist();
    
    // Initialize connectivity service for sync check
    final connectivityService = ConnectivityService();
    await connectivityService.initialize();
    
    // If online, try to sync in background
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://mjlurwscaotbziijzymq.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1qbHVyd3NjYW90YnppaWp6eW1xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDgzNjA1NTAsImV4cCI6MjA2MzkzNjU1MH0.2wnp7hupGpdcUiFxTagBvMkK3Ez-_5zqC4tJGineujk',
  );

  // Initialize local storage first
  try {
    print('🚀 Initializing local storage...');
    await LocalStorageService().init();
    print('✅ Local storage initialized');
  } catch (e) {
    print('❌ Error initializing local storage: $e');
  }

  // Initialize connectivity service
  try {
    print('🌐 Initializing connectivity service...');
    await ConnectivityService().initialize();
    print('✅ Connectivity service initialized');
  } catch (e) {
    print('❌ Error initializing connectivity service: $e');
  }

  // Initialize EventProvider
  try {
    print('📅 Initializing event provider...');
    await EventProvider().init();
    print('✅ Event provider initialized');
  } catch (e) {
    print('❌ Error initializing event provider: $e');
  }

  runApp(const MyApp());

  // Initialize other services after app starts
  try {
    await NotificationService().init();
    await _requestPermissions();

    final bool alarmInitialized = await AndroidAlarmManager.initialize();
    print('Alarm Manager initialized: $alarmInitialized');

    if (alarmInitialized) {
      const int helloAlarmID = 0;
      final bool alarmSet = await AndroidAlarmManager.periodic(
        const Duration(minutes: 15),
        helloAlarmID,
        alarmCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );
      print('Alarm set: $alarmSet');
    }
  } catch (e) {
    print('Error initializing services: $e');
  }
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