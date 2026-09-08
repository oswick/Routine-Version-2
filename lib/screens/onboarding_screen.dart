import 'package:flutter/material.dart';
import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
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
    if (state == AppLifecycleState.resumed) _refreshPermissions();
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
    final scheme = theme.colorScheme;
    final spanish = _isSpanish;

    final permissions = [
      _PermissionItem(
        icon: Icons.notifications_outlined,
        title: spanish ? 'Notificaciones' : 'Notifications',
        description: spanish ? 'Recibe tus recordatorios de eventos.' : 'Receive your event reminders.',
        granted: _notificationsGranted,
        buttonLabel: spanish ? 'Permitir' : 'Allow',
        onPressed: _notificationsGranted || _requesting ? null : _requestNotificationPermission,
      ),
      _PermissionItem(
        icon: Icons.battery_saver_outlined,
        title: spanish ? 'Batería sin restricciones' : 'Unrestricted battery',
        description: spanish ? 'Evita retrasos en los recordatorios en segundo plano.' : 'Prevents background reminders from being delayed.',
        granted: _batteryGranted,
        buttonLabel: spanish ? 'Configurar' : 'Set up',
        onPressed: _batteryGranted || _requesting ? null : _requestBatteryPermission,
      ),
      _PermissionItem(
        icon: Icons.alarm_outlined,
        title: spanish ? 'Alarmas exactas' : 'Exact alarms',
        description: spanish ? 'Permite que los eventos ocurran a la hora exacta.' : 'Lets scheduled events trigger at their exact time.',
        granted: _exactAlarmGranted,
        buttonLabel: spanish ? 'Permitir' : 'Allow',
        onPressed: _exactAlarmGranted || _requesting ? null : _requestExactAlarmPermission,
      ),
    ];

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 44, maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(Icons.checklist_rounded, color: scheme.onPrimaryContainer, size: 28),
                      ),
                      const Spacer(),
                      if (!_loading && _allGranted)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            spanish ? 'Listo' : 'Ready',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 34),
                  Text(
                    spanish ? 'Haz que Routine funcione por ti.' : 'Let Routine work for you.',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    spanish
                        ? 'Solo necesitamos unos accesos para que tus eventos y recordatorios funcionen de forma fiable.'
                        : 'Routine needs a few permissions so your events and reminders work reliably.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        for (var i = 0; i < permissions.length; i++) ...[
                          _PermissionTile(item: permissions[i]),
                          if (i != permissions.length - 1)
                            Divider(height: 1, indent: 68, endIndent: 12, color: scheme.outlineVariant),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  M3EButton.icon(
                    onPressed: _loading ? null : _complete,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(spanish ? 'Continuar' : 'Continue'),
                    style: M3EButtonStyle.filled,
                    size: M3EButtonSize.lg,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    spanish
                        ? 'Puedes cambiar estos permisos después desde Ajustes de Android.'
                        : 'You can change these permissions later from Android Settings.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _allGranted => _notificationsGranted && _batteryGranted && _exactAlarmGranted;
}

class _PermissionItem {
  const _PermissionItem({
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
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({required this.item});

  final _PermissionItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: item.granted ? scheme.primaryContainer : scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              item.granted ? Icons.check_rounded : item.icon,
              color: item.granted ? scheme.onPrimaryContainer : scheme.onSecondaryContainer,
              size: 23,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(
                  item.description,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.25),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (item.granted)
            Icon(Icons.check_circle_rounded, color: scheme.primary, size: 24)
          else
            M3EButton.text(onPressed: item.onPressed, child: Text(item.buttonLabel)),
        ],
      ),
    );
  }
}
