import 'package:flutter/material.dart';
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

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Start the app first, then initialize background services
  runApp(const MyApp());
  
  // Initialize services in a try-catch block to prevent startup crashes
  try {
    // Initialize notification service
    await NotificationService().init();
    
    // Request permissions
    await _requestPermissions();
    
    // Initialize Android Alarm Manager
    final bool alarmInitialized = await AndroidAlarmManager.initialize();
    print('Alarm Manager initialized: $alarmInitialized');
    
    if (alarmInitialized) {
      // Setup periodic background check (every 15 minutes)
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
    return MaterialApp(
      title: 'Routine',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData.light(
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark(
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}