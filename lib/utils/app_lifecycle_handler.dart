// lib/utils/app_lifecycle_handler.dart
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../providers/event_provider.dart';
import '../utils/notification_service.dart';

class AppLifecycleHandler extends WidgetsBindingObserver {
  static AppLifecycleHandler? _instance;
  BuildContext? _context;

  AppLifecycleHandler._internal();

  static AppLifecycleHandler get instance {
    _instance ??= AppLifecycleHandler._internal();
    return _instance!;
  }

  void initialize(BuildContext context) {
    _context = context;
    WidgetsBinding.instance.addObserver(this);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    print('🔄 AppLifecycle: App lifecycle changed: $state');
    
    switch (state) {
      case AppLifecycleState.resumed:
        // La app volvió al primer plano
        _onAppResumed();
        break;
      case AppLifecycleState.paused:
        // La app pasó a segundo plano
        _onAppPaused();
        break;
      case AppLifecycleState.detached:
        // La app se está cerrando
        _onAppDetached();
        break;
      default:
        break;
    }
  }

  void _onAppResumed() async {
    print('📱 AppLifecycle: App resumed - checking notifications...');
    
    if (_context != null) {
      try {
        // Reprogramar notificaciones por si se perdieron
        await NotificationService().ensureScheduledNotificationsExist();
        
        // También reprogramar desde el provider
        final eventProvider = Provider.of<EventProvider>(_context!, listen: false);
        await eventProvider.rescheduleAllNotifications();
        
        // Verificar estado de sincronización
        await eventProvider.loadEvents();
        
        print('✅ Notifications and events refreshed on app resume');
      } catch (e) {
        print('❌ Error refreshing on app resume: $e');
      }
    }
  }

  void _onAppPaused() {
    print('📱 AppLifecycle: App paused');
    // Solo manejo de notificaciones, no auth (eso lo maneja NavScreen)
  }

  void _onAppDetached() {
    print('📱 AppLifecycle: App detached');
    // Cleanup si es necesario
  }

  // Método para verificar manualmente las notificaciones
  Future<void> checkNotificationStatus() async {
    if (_context != null) {
      final status = await NotificationService().getNotificationStatus();
      
      if (status['sync_needed'] == true) {
        print('⚠️ Notification sync needed - rescheduling...');
        await NotificationService().ensureScheduledNotificationsExist();
        
        final eventProvider = Provider.of<EventProvider>(_context!, listen: false);
        await eventProvider.rescheduleAllNotifications();
      }
    }
  }
}