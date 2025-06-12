import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:myapp/screens/nav_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'utils/notification_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

// This function will be called periodically by the alarm manager
@pragma('vm:entry-point')
void alarmCallback() async {
  try {
    await NotificationService().init();
    await NotificationService().ensureScheduledNotificationsExist();
  } catch (e) {
    // Consider logging this error to a crash reporting tool
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://mjlurwscaotbziijzymq.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1qbHVyd3NjYW90YnppaWp6eW1xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDgzNjA1NTAsImV4cCI6MjA2MzkzNjU1MH0.2wnp7hupGpdcUiFxTagBvMkK3Ez-_5zqC4tJGineujk',
  );

  runApp(const MyApp());

  try {
    await NotificationService().init();
    await _requestPermissions();

    final bool alarmInitialized = await AndroidAlarmManager.initialize();
    if (alarmInitialized) {
      const int helloAlarmID = 0;
      await AndroidAlarmManager.periodic(
        const Duration(minutes: 15),
        helloAlarmID,
        alarmCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );
    }
  } catch (e) {
    // Consider logging this error to a crash reporting tool
  }
}

Future<void> _requestPermissions() async {
  try {
    await [
      Permission.notification,
      Permission.scheduleExactAlarm,
      Permission.ignoreBatteryOptimizations,
    ].request();
  } catch (e) {
    // Consider logging this error to a crash reporting tool
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
    );
  }
}
