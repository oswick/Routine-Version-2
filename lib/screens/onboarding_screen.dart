import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/screens/nav_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  bool _notificationsGranted = false;
  bool _batteryGranted = false;
  bool _exactAlarmGranted = false;
  bool _loading = true;
  bool _requesting = false;

  bool get _isSpanish => Localizations.localeOf(context).languageCode == 'es';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissions();
    }
  }

  Future<void> _refreshPermissions() async {
    try {
      final notification = await Permission.notification.status;
      final battery = await Permission.ignoreBatteryOptimizations.status;
      final exactAlarm = await Permission.scheduleExactAlarm.status;

      if (!mounted) return;
      setState(() {
        _notificationsGranted = notification.isGranted;
        _batteryGranted = battery.isGranted;
        _exactAlarmGranted = exactAlarm.isGranted;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestNotificationPermission() async {
    setState(() => _requesting = true);
    await Permission.notification.request();
    await _refreshPermissions();
    if (mounted) setState(() => _requesting = false);
  }

  Future<void> _requestBatteryPermission() async {
    setState(() => _requesting = true);
    try {
      await Permission.ignoreBatteryOptimizations.request();
    } catch (_) {
      await openAppSettings();
    }
    await _refreshPermissions();
    if (mounted) setState(() => _requesting = false);
  }

  Future<void> _requestExactAlarmPermission() async {
    setState(() => _requesting = true);
    try {
      await Permission.scheduleExactAlarm.request();
    } catch (_) {}
    await _refreshPermissions();
    if (mounted) setState(() => _requesting = false);
  }

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainHomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spanish = _isSpanish;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications_active_outlined,
                      size: 36,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    spanish ? 'Prepara Routine' : 'Get Routine ready',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    spanish
                        ? 'Activa estos accesos para que tus recordatorios lleguen a tiempo y funcionen de forma fiable.'
                        : 'Enable these permissions so your reminders arrive on time and work reliably.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _PermissionTile(
                    icon: Icons.notifications_outlined,
                    title: spanish ? 'Notificaciones' : 'Notifications',
                    description: spanish
                        ? 'Recibe tus recordatorios de eventos.'
                        : 'Receive your event reminders.',
                    granted: _notificationsGranted,
                    buttonLabel: spanish ? 'Permitir' : 'Allow',
                    onPressed: _notificationsGranted || _requesting
                        ? null
                        : _requestNotificationPermission,
                  ),
                  const SizedBox(height: 12),
                  _PermissionTile(
                    icon: Icons.battery_saver_outlined,
                    title: spanish
                        ? 'Sin restricciones de batería'
                        : 'Battery optimization',
                    description: spanish
                        ? 'Evita que Android retrase los recordatorios en segundo plano.'
                        : 'Prevents Android from delaying reminders in the background.',
                    granted: _batteryGranted,
                    buttonLabel: spanish ? 'Configurar' : 'Set up',
                    onPressed: _batteryGranted || _requesting
                        ? null
                        : _requestBatteryPermission,
                  ),
                  const SizedBox(height: 12),
                  _PermissionTile(
                    icon: Icons.alarm_outlined,
                    title: spanish ? 'Alarmas exactas' : 'Exact alarms',
                    description: spanish
                        ? 'Permite que los eventos programados suenen a la hora exacta.'
                        : 'Lets scheduled events trigger at their exact time.',
                    granted: _exactAlarmGranted,
                    buttonLabel: spanish ? 'Permitir' : 'Allow',
                    onPressed: _exactAlarmGranted || _requesting
                        ? null
                        : _requestExactAlarmPermission,
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _loading ? null : _complete,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(spanish ? 'Continuar' : 'Continue'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    spanish
                        ? 'Puedes cambiar estos permisos después desde la configuración de Android.'
                        : 'You can change these permissions later from Android settings.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.granted,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool granted;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (granted)
              Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
              )
            else
              TextButton(onPressed: onPressed, child: Text(buttonLabel)),
          ],
        ),
      ),
    );
  }
}
