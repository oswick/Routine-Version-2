import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'utils/notification_service.dart';
import 'package:permission_handler/permission_handler.dart'; // Importa la librería

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  await _requestPermissions(); // Solicita permisos
  runApp(const MyApp());
}

Future<void> _requestPermissions() async {
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
  if (await Permission.scheduleExactAlarm.isDenied) {
    await Permission.scheduleExactAlarm.request();
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
