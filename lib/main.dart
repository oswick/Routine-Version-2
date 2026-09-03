// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:myapp/config/app_config.dart';
import 'package:myapp/l10n/app_localizations.dart';
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

// CRÍTICO: re-exportar el background handler aquí para que el linker de Dart
// lo incluya en el build. Sin este import el compilador puede eliminarlo.
// La función está definida en notification_service.dart como top-level.
// ignore: unused_import
export 'utils/notification_service.dart' show notificationBackgroundHandler;

// TODO: reemplaza esto por el color de marca de tu app (seed color).
// Si no tienes un color de marca fijo, puedes dejarlo tal cual:
// dynamicColoring:true hará que el sistema (Material You / Android 12+)
// lo sobreescriba cuando esté disponible; este seed queda solo como
// fallback en iOS/desktop o dispositivos sin dynamic color.
const Color _seedColor = Color(0xFF6750A4);

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
    // M3EMaterialApp reemplaza a MaterialApp + DynamicColorBuilder:
    // ya gestiona internamente el brightness del sistema, el
    // ThemeMode y el dynamic color (Material You / Android 12+),
    // así que ya no hace falta envolver el árbol a mano.
    return M3EMaterialApp(
      title: 'Routine',
      debugShowCheckedModeBanner: false,
      drawUnderSystemBars: true,

      // Tema base M3 Expressive (claro), a partir del cual se derivan
      // el tema oscuro y el dynamic color.
      data: M3EThemeData.light(seedColor: _seedColor),
      autoTheming: true, // sigue el brightness del sistema
      dynamicColoring: true, // usa Material You cuando esté disponible

      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('es'),
      ],

      home: const MainHomeScreen(),
    );
  }
}