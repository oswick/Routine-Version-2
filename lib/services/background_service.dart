// lib/services/background_service.dart
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import '../utils/notification_service.dart';
import '../models/event.dart';
import '../services/local_stogare_service.dart';

class BackgroundService {
  static const String _taskName = "rescheduleNotifications";
  static const String _uniqueName = "rescheduleNotificationsTask";
  
  static Future<void> initWorkManager() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );
    print('🔧 WorkManager initialized');
  }

  static Future<void> registerRescheduleTask() async {
    await Workmanager().registerPeriodicTask(
      _uniqueName,
      _taskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.notRequired,
      ),
    );
    print('📆 Reschedule task registered');
  }

  static Future<void> cancelAllTasks() async {
    await Workmanager().cancelAll();
  }
}

// Callback que se ejecuta en segundo plano
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('🔄 Background task executing: $task');
    
    try {
      switch (task) {
        case BackgroundService._taskName:
          await _rescheduleNotifications();
          break;
        default:
          print('❌ Unknown background task: $task');
          return Future.value(false);
      }
      
      print('✅ Background task completed successfully');
      return Future.value(true);
    } catch (e) {
      print('❌ Background task failed: $e');
      return Future.value(false);
    }
  });
}

Future<void> _rescheduleNotifications() async {
  try {
    // Inicializar servicios necesarios
    final notificationService = NotificationService();
    await notificationService.init();
    
    final localStorage = LocalStorageService();
    await localStorage.init();
    
    // Obtener eventos activos
    final events = localStorage.getAllEvents();
    final now = DateTime.now();
    
    print('📅 Checking ${events.length} events for rescheduling...');
    
    for (final event in events) {
      if (event.isCompleted || event.isDeleted) continue;
      
      // Para eventos repetitivos
      if (event.repeatDays.isNotEmpty) {
        await _rescheduleRepetitiveEvent(event, notificationService, now);
      } 
      // Para eventos únicos
      else {
        await _rescheduleSingleEvent(event, notificationService, now);
      }
    }
    
    print('🔔 Notification rescheduling completed');
  } catch (e) {
    print('❌ Error in background notification rescheduling: $e');
  }
}

Future<void> _rescheduleRepetitiveEvent(
  Event event, 
  NotificationService notificationService, 
  DateTime now
) async {
  for (int day in event.repeatDays) {
    // Calcular próxima ocurrencia para este día
    final nextOccurrence = _getNextOccurrence(day, event.startTime, now);
    
    if (nextOccurrence.isAfter(now)) {
      final notificationId = event.id.hashCode + day;
      
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
            event.description ?? 'Recordatorio de evento',
            nextEndTime,
            null,
          );
        }
      }
    }
  }
}

Future<void> _rescheduleSingleEvent(
  Event event, 
  NotificationService notificationService, 
  DateTime now
) async {
  if (event.startTime.isAfter(now)) {
    final notificationId = event.id.hashCode;
    
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
    }
    
    // Programar notificación de fin si existe
    if (event.endTime != null && event.endTime!.isAfter(now)) {
      final endNotificationId = notificationId + 10000;
      final isEndAlreadyScheduled = pendingNotifications.any((n) => n.id == endNotificationId);
      
      if (!isEndAlreadyScheduled) {
        await notificationService.scheduleEndNotification(
          notificationId,
          event.title,
          event.description ?? 'Recordatorio de evento',
          event.endTime!,
          null,
        );
      }
    }
  }
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