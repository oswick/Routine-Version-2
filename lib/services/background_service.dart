// lib/services/background_service.dart
// MEJORAS:
// 1. Usa el mismo esquema de IDs que EventProvider para no crear colisiones
// 2. _nextOccurrence extraído como helper compartido
// 3. Logs en inglés (contexto de isolate, sin l10n)

import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import '../utils/notification_service.dart';
import '../models/event.dart';
import '../services/local_stogare_service.dart';

class BackgroundService {
  static const String _taskName = 'rescheduleNotifications';
  static const String _uniqueName = 'rescheduleNotificationsTask';

  static bool _isInitialized = false;

  static Future<void> initWorkManager() async {
    if (_isInitialized) return;
    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );
      _isInitialized = true;
      debugPrint('🔧 WorkManager initialized');
    } catch (e) {
      _isInitialized = false;
      debugPrint('❌ WorkManager init failed: $e');
      rethrow;
    }
  }

  static Future<void> registerRescheduleTask() async {
    if (!_isInitialized) await initWorkManager();
    try {
      await Workmanager().cancelByUniqueName(_uniqueName);
      await Workmanager().registerPeriodicTask(
        _uniqueName,
        _taskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.notRequired),
      );
      debugPrint('📆 Reschedule task registered');
    } catch (e) {
      debugPrint('❌ Failed to register task: $e');
    }
  }

  static Future<void> cancelAllTasks() async {
    if (_isInitialized) await Workmanager().cancelAll();
  }

  static bool get isInitialized => _isInitialized;
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    debugPrint('🔄 Background task: $task');
    try {
      if (task == BackgroundService._taskName) {
        await _rescheduleNotifications();
      }
      return true;
    } catch (e) {
      debugPrint('❌ Background task failed: $e');
      return false;
    }
  });
}

// ── Notification ID scheme (must match EventProvider) ─────────────────────────
// BASE ids only — NotificationService adds +10_000 for end notifications internally.
//   Single event      : _notifId(eventId)
//   Repeat on day N   : _notifId(eventId, day: N)
const int _hashMod = 2147473639;

int _notifId(String eventId, {int day = 0}) {
  final base = eventId.hashCode.abs() % _hashMod;
  return base + day;
}

// ─────────────────────────────────────────────────────────────────────────────
Future<void> _rescheduleNotifications() async {
  final notifService = NotificationService();
  await notifService.init();

  final storage = LocalStorageService();
  await storage.init();

  final events = storage.getAllEvents();
  final now = DateTime.now();
  int count = 0;

  for (final event in events) {
    if (event.isCompleted || event.isDeleted) continue;

    if (event.repeatDays.isNotEmpty) {
      if (await _rescheduleRepeat(event, notifService, now)) count++;
    } else {
      if (await _rescheduleSingle(event, notifService, now)) count++;
    }
  }

  debugPrint('🔔 Background: rescheduled $count events');
}

Future<bool> _rescheduleRepeat(
  Event event,
  NotificationService svc,
  DateTime now,
) async {
  bool any = false;
  final pending = await svc.getPendingNotifications();
  final pendingIds = pending.map((n) => n.id).toSet();

  for (final day in event.repeatDays) {
    final baseId = _notifId(event.id, day: day);
    final endId = baseId + 10000; // service stores end at baseId + 10_000
    final nextStart = _nextOccurrence(day, event.startTime, now);

    if (nextStart.isAfter(now) && !pendingIds.contains(baseId)) {
      await svc.scheduleNotification(
          baseId, event.title, event.description ?? '', nextStart, null);
      any = true;
    }

    if (event.endTime != null) {
      final nextEnd = _nextOccurrence(day, event.endTime!, now);
      if (nextEnd.isAfter(now) && !pendingIds.contains(endId)) {
        // Pass BASE id — service adds +10_000 internally
        await svc.scheduleEndNotification(
            baseId,
            event.title,
            event.description ?? '',
            nextEnd,
            null);
      }
    }
  }
  return any;
}

Future<bool> _rescheduleSingle(
  Event event,
  NotificationService svc,
  DateTime now,
) async {
  if (!event.startTime.isAfter(now)) return false;

  final baseId = _notifId(event.id);
  final endId = baseId + 10000; // service stores end at baseId + 10_000
  final pending = await svc.getPendingNotifications();
  final pendingIds = pending.map((n) => n.id).toSet();

  if (!pendingIds.contains(baseId)) {
    await svc.scheduleNotification(
        baseId, event.title, event.description ?? '', event.startTime, null);

    if (event.endTime != null && event.endTime!.isAfter(now)) {
      if (!pendingIds.contains(endId)) {
        // Pass BASE id — service adds +10_000 internally
        await svc.scheduleEndNotification(
            baseId,
            event.title,
            event.description ?? '',
            event.endTime!,
            null);
      }
    }
    return true;
  }
  return false;
}

DateTime _nextOccurrence(int targetDay, DateTime eventTime, DateTime now) {
  int ahead = (targetDay - now.weekday + 7) % 7;
  if (ahead == 0) {
    final todayAt = DateTime(now.year, now.month, now.day,
        eventTime.hour, eventTime.minute);
    if (todayAt.isAfter(now)) return todayAt;
    ahead = 7;
  }
  final d = now.add(Duration(days: ahead));
  return DateTime(d.year, d.month, d.day, eventTime.hour, eventTime.minute);
}