import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'utils/notification_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

// This function will be called periodically by the alarm manager
@pragma('vm:entry-point')
void alarmCallback() async {
  // Add a try-catch block to prevent crashes
  try {
    print('Alarm triggered at ${DateTime.now()}');
    // Initialize notification service
    await NotificationService().init();
    // Check and reschedule notifications if needed
    await NotificationService().ensureScheduledNotificationsExist();
  } catch (e) {
    print('Error in alarm callback: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://mjlurwscaotbziijzymq.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1qbHVyd3NjYW90YnppaWp6eW1xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDgzNjA1NTAsImV4cCI6MjA2MzkzNjU1MH0.2wnp7hupGpdcUiFxTagBvMkK3Ez-_5zqC4tJGineujk',
  );

  runApp(const MyApp());

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
    Map<Permission, PermissionStatus> statuses =
        await [
          Permission.notification,
          Permission.scheduleExactAlarm,
          // Optional: Request background activity permissions
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
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          title: 'Routine',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true, colorScheme: lightDynamic),
          darkTheme: ThemeData(useMaterial3: true, colorScheme: darkDynamic),
          themeMode: ThemeMode.system,
          home: const HomeScreen(),
        );
      },
    );
  }
}
