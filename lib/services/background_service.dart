// lib/services/background_service.dart
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import '../utils/notification_service.dart';
import '../models/event.dart';
import '../services/local_stogare_service.dart';

class BackgroundService {
  static const String _taskName = "rescheduleNotifications";
  static const String _uniqueName = "rescheduleNotificationsTask";
  
  static bool _isInitialized = false;
  
  static Future<void> initWorkManager() async {
    if (_isInitialized) {
      print('🔧 WorkManager already initialized, skipping...');
      return;
    }
    
    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );
      
      _isInitialized = true;
      print('🔧 WorkManager initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize WorkManager: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  static Future<void> registerRescheduleTask() async {
    // Asegurar que WorkManager está inicializado antes de registrar tareas
    if (!_isInitialized) {
      print('⚠️ WorkManager not initialized, initializing now...');
      await initWorkManager();
    }
    
    try {
      // Cancelar la tarea existente primero para evitar conflictos
      await Workmanager().cancelByUniqueName(_uniqueName);
      
      // Registrar la nueva tarea
      await Workmanager().registerPeriodicTask(
        _uniqueName,
        _taskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.notRequired,
        ),
      );
      
      print('📆 Reschedule task registered successfully');
    } catch (e) {
      print('❌ Failed to register reschedule task: $e');
      
      // Si falla, intentar inicializar de nuevo
      _isInitialized = false;
      await initWorkManager();
      
      // Intentar registrar una vez más
      try {
        await Workmanager().registerPeriodicTask(
          _uniqueName,
          _taskName,
          frequency: const Duration(minutes: 15),
          constraints: Constraints(
            networkType: NetworkType.notRequired,
          ),
        );
        print('📆 Reschedule task registered on retry');
      } catch (retryError) {
        print('❌ Failed to register task on retry: $retryError');
      }
    }
  }

  static Future<void> cancelAllTasks() async {
    try {
      if (_isInitialized) {
        await Workmanager().cancelAll();
        print('🗑️ All WorkManager tasks cancelled');
      } else {
        print('⚠️ WorkManager not initialized, cannot cancel tasks');
      }
    } catch (e) {
      print('❌ Error cancelling WorkManager tasks: $e');
    }
  }

  static bool get isInitialized => _isInitialized;
}

// Callback que se ejecuta en segundo plano
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('🔄 Background task executing: $task at ${DateTime.now()}');
    
    try {
      switch (task) {
        case BackgroundService._taskName:
          await _rescheduleNotifications();
          break;
        default:
          print('❌ Unknown background task: $task');
          return Future.value(false);
      }
      
      print('✅ Background task completed successfully at ${DateTime.now()}');
      return Future.value(true);
    } catch (e) {
      print('❌ Background task failed: $e');
      return Future.value(false);
    }
  });
}

Future<void> _rescheduleNotifications() async {
  try {
    print('📅 Starting notification rescheduling process...');
    
    // Inicializar servicios necesarios
    final notificationService = NotificationService();
    await notificationService.init();
    
    final localStorage = LocalStorageService();
    await localStorage.init();
    
    // Obtener eventos activos
    final events = localStorage.getAllEvents();
    final now = DateTime.now();
    
    print('📅 Checking ${events.length} events for rescheduling...');
    
    int rescheduledCount = 0;
    
    for (final event in events) {
      if (event.isCompleted || event.isDeleted) continue;
      
      // Para eventos repetitivos
      if (event.repeatDays.isNotEmpty) {
        final scheduled = await _rescheduleRepetitiveEvent(event, notificationService, now);
        if (scheduled) rescheduledCount++;
      } 
      // Para eventos únicos
      else {
        final scheduled = await _rescheduleSingleEvent(event, notificationService, now);
        if (scheduled) rescheduledCount++;
      }
    }
    
    print('🔔 Notification rescheduling completed - $rescheduledCount events rescheduled');
  } catch (e) {
    print('❌ Error in background notification rescheduling: $e');
  }
}

Future<bool> _rescheduleRepetitiveEvent(
  Event event, 
  NotificationService notificationService, 
  DateTime now
) async {
  bool anyScheduled = false;
  
  for (int day in event.repeatDays) {
    // Calcular próxima ocurrencia para este día
    final nextOccurrence = _getNextOccurrence(day, event.startTime, now);
    
    if (nextOccurrence.isAfter(now)) {
      final notificationId = event.id.hashCode + day;
      
      try {
        // Verificar si ya está programada
        final pendingNotifications = await notificationService.getPendingNotifications();
        final isAlreadyScheduled = pendingNotifications.any((n) => n.id == notificationId);
        
        if (!isAlreadyScheduled) {
          await notificationService.scheduleNotification(
            notificationId,
            event.title,
            event.description ?? 'Recordatorio de evento',
            nextOccurrence,
            null,
          );
          print('🔔 Rescheduled repetitive event: ${event.title} for ${_formatDay(day)}');
          anyScheduled = true;
        }
        
        // Programar notificación de fin si existe
        if (event.endTime != null) {
          final endNotificationId = notificationId + 10000;
          final nextEndTime = _getNextOccurrence(day, event.endTime!, now);
          
          final isEndAlreadyScheduled = pendingNotifications.any((n) => n.id == endNotificationId);
          if (!isEndAlreadyScheduled && nextEndTime.isAfter(now)) {
            await notificationService.scheduleEndNotification(
              notificationId,
              event.title,
              event.description ?? 'Evento terminado',
              nextEndTime,
              null,
            );
          }
        }
      } catch (e) {
        print('❌ Error rescheduling repetitive event ${event.title}: $e');
      }
    }
  }
  
  return anyScheduled;
}

Future<bool> _rescheduleSingleEvent(
  Event event, 
  NotificationService notificationService, 
  DateTime now
) async {
  if (event.startTime.isAfter(now)) {
    final notificationId = event.id.hashCode;
    
    try {
      // Verificar si ya está programada
      final pendingNotifications = await notificationService.getPendingNotifications();
      final isAlreadyScheduled = pendingNotifications.any((n) => n.id == notificationId);
      
      if (!isAlreadyScheduled) {
        await notificationService.scheduleNotification(
          notificationId,
          event.title,
          event.description ?? 'Recordatorio de evento',
          event.startTime,
          null,
        );
        print('🔔 Rescheduled single event: ${event.title}');
        
        // Programar notificación de fin si existe
        if (event.endTime != null && event.endTime!.isAfter(now)) {
          final endNotificationId = notificationId + 10000;
          final isEndAlreadyScheduled = pendingNotifications.any((n) => n.id == endNotificationId);
          
          if (!isEndAlreadyScheduled) {
            await notificationService.scheduleEndNotification(
              notificationId,
              event.title,
              event.description ?? 'Evento terminado',
              event.endTime!,
              null,
            );
          }
        }
        
        return true;
      }
    } catch (e) {
      print('❌ Error rescheduling single event ${event.title}: $e');
    }
  }
  
  return false;
}

DateTime _getNextOccurrence(int targetDay, DateTime eventTime, DateTime now) {
  int daysUntilTarget = (targetDay - now.weekday + 7) % 7;
  if (daysUntilTarget == 0) {
    // Es hoy, verificar si ya pasó la hora
    final todayAtEventTime = DateTime(
      now.year,
      now.month,
      now.day,
      eventTime.hour,
      eventTime.minute,
    );
    
    if (todayAtEventTime.isAfter(now)) {
      return todayAtEventTime;
    } else {
      daysUntilTarget = 7; // Programar para la próxima semana
    }
  }
  
  final nextDate = now.add(Duration(days: daysUntilTarget));
  return DateTime(
    nextDate.year,
    nextDate.month,
    nextDate.day,
    eventTime.hour,
    eventTime.minute,
  );
}

String _formatDay(int day) {
  switch (day) {
    case 1: return 'Lunes';
    case 2: return 'Martes';
    case 3: return 'Miércoles';
    case 4: return 'Jueves';
    case 5: return 'Viernes';
    case 6: return 'Sábado';
    case 7: return 'Domingo';
    default: return 'Día $day';
  }
}