// lib/utils/notification_service.dart
//
// CONTRATO DE IDs (seguido aquí, en EventProvider y BackgroundService):
//
//   scheduleNotification(id, ...)      → registra con el ID exacto
//   scheduleEndNotification(id, ...)   → registra con (id + 10_000)
//   cancelNotification(id)             → cancela id Y (id + 10_000)
//
// El caller SIEMPRE pasa el ID base:
//   Evento único      : eventId.hashCode
//   Repetitivo día N  : eventId.hashCode + N   (N = 1..7)

import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class ScheduledNotificationData {
  final int id;
  final String title;
  final String body;
  final DateTime scheduledDate;
  final bool isEndNotification;
  final String? eventId;

  ScheduledNotificationData({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledDate,
    this.isEndNotification = false,
    this.eventId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'scheduledDate': scheduledDate.millisecondsSinceEpoch,
      'isEndNotification': isEndNotification,
      'eventId': eventId,
    };
  }

  factory ScheduledNotificationData.fromJson(Map<String, dynamic> json) {
    return ScheduledNotificationData(
      id: json['id'],
      title: json['title'],
      body: json['body'],
      scheduledDate:
          DateTime.fromMillisecondsSinceEpoch(json['scheduledDate']),
      isEndNotification: json['isEndNotification'] ?? false,
      eventId: json['eventId'] as String?,
    );
  }
}

class NotificationService {
  static final NotificationService _notificationService =
      NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  factory NotificationService() => _notificationService;
  NotificationService._internal();

  List<PendingNotificationRequest>? _pendingNotificationsCache;
  DateTime? _cacheTime;

  Future<void> init() async {
    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInitSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    tz.initializeTimeZones();
    await _createNotificationChannel();
    await _cleanOrphanNotifications();
  }

  /// Tap sobre una notificación normal.
  /// No abre la app por sí misma; solo se registra el evento si Flutter está activo.
  void _onNotificationResponse(NotificationResponse response) {
    if (response.notificationResponseType ==
        NotificationResponseType.selectedNotification) {
      final firedId = int.tryParse(response.payload ?? '');
      debugPrint('🔔 Notification tapped: $firedId');
    }
  }

  // Se conserva esta API porque EventProvider la registra durante su inicialización.
  // Las acciones de notificación fueron eliminadas para mantener las notificaciones
  // como recordatorios simples y evitar acciones que no funcionaban de forma fiable
  // cuando Android ejecutaba la app en segundo plano o bloqueada.
  void Function(String eventId)? _markDoneCallback;

  void registerMarkDoneCallback(void Function(String eventId) callback) {
    _markDoneCallback = callback;
    debugPrint('ℹ️ NotificationService: markDone callback registered (legacy)');
  }

  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'your_channel_id',
      'your_channel_name',
      description: 'your_channel_description',
      importance: Importance.max,
      enableVibration: true,
      showBadge: true,
      enableLights: true,
      playSound: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> requestNotificationPermission() async {
    try {
      if (Platform.isAndroid) {
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }
  }

  Future<void> _cleanOrphanNotifications() async {
    try {
      final pending =
          await flutterLocalNotificationsPlugin.pendingNotificationRequests();
      final saved = await _getScheduledNotificationsData();
      final savedIds = saved.map((n) => n.id).toSet();
      int canceledCount = 0;

      for (final p in pending) {
        if (!savedIds.contains(p.id)) {
          await flutterLocalNotificationsPlugin.cancel(p.id);
          canceledCount++;
        }
      }

      if (canceledCount > 0) {
        _invalidateCache();
        debugPrint('🧹 Cleaned $canceledCount orphan notifications');
      }
    } catch (e) {
      debugPrint('Error cleaning orphan notifications: $e');
    }
  }

  Future<void> scheduleNotification(
    int id,
    String title,
    String body,
    DateTime scheduledDate,
    BuildContext? context, {
    String? eventId,
  }) async {
    try {
      if (!scheduledDate.isAfter(DateTime.now())) return;

      final notif = ScheduledNotificationData(
        id: id,
        title: title,
        body: body.isEmpty ? title : body,
        scheduledDate: scheduledDate,
        eventId: eventId,
      );

      await _showNotificationInternal(notif);
      await _saveNotificationData(notif);
      _invalidateCache();
      debugPrint('📅 Scheduled start notif id=$id at $scheduledDate');
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
    }
  }

  Future<void> scheduleEndNotification(
    int id,
    String title,
    String body,
    DateTime scheduledDate,
    BuildContext? context, {
    String? eventId,
  }) async {
    try {
      final endId = id + 10000;

      if (!scheduledDate.isAfter(DateTime.now())) return;

      final notif = ScheduledNotificationData(
        id: endId,
        title: '✅ $title',
        body: body.isEmpty ? title : body,
        scheduledDate: scheduledDate,
        isEndNotification: true,
        eventId: eventId,
      );

      await _showNotificationInternal(notif);
      await _saveNotificationData(notif);
      _invalidateCache();
      debugPrint(
        '📅 Scheduled end notif baseId=$id → id=$endId at $scheduledDate',
      );
    } catch (e) {
      debugPrint('Error scheduling end notification: $e');
    }
  }

  Future<void> _showNotificationInternal(
    ScheduledNotificationData notif,
  ) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      notif.id,
      notif.title,
      notif.body,
      tz.TZDateTime.from(notif.scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'your_channel_id',
          'your_channel_name',
          channelDescription: 'your_channel_description',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/launcher_icon',
          enableVibration: true,
          styleInformation: DefaultStyleInformation(true, true),
          autoCancel: true,
          fullScreenIntent: false,
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.public,
          showWhen: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: notif.id.toString(),
    );
  }

  Future<ScheduledNotificationData?> getNotificationDataById(int id) =>
      _getNotificationDataById(id);

  Future<void> cancelSingleNotification(int id) async {
    try {
      await flutterLocalNotificationsPlugin.cancel(id);
      await _removeNotificationData(id);
      _invalidateCache();
      debugPrint('❌ Cancelled single notif id=$id');
    } catch (e) {
      debugPrint('Error cancelling single notification: $e');
    }
  }

  Future<void> snoozeNotification(int firedId) async {
    final stored = await _getNotificationDataById(firedId);
    await flutterLocalNotificationsPlugin.cancel(firedId);
    await _removeNotificationData(firedId);

    final snoozeTime = DateTime.now().add(const Duration(minutes: 5));
    final notif = ScheduledNotificationData(
      id: firedId,
      title: stored?.title ?? '⏰ Recordatorio',
      body: stored?.body ?? 'Evento pospuesto 5 min',
      scheduledDate: snoozeTime,
      isEndNotification: stored?.isEndNotification ?? false,
      eventId: stored?.eventId,
    );

    await _showNotificationInternal(notif);
    await _saveNotificationData(notif);
    _invalidateCache();
    debugPrint('⏸️ Snoozed notif id=$firedId → $snoozeTime');
  }

  Future<void> cancelNotification(int id) async {
    try {
      await flutterLocalNotificationsPlugin.cancel(id);
      await _removeNotificationData(id);

      final endId = id + 10000;
      await flutterLocalNotificationsPlugin.cancel(endId);
      await _removeNotificationData(endId);

      _invalidateCache();
      debugPrint('❌ Cancelled notif pair: start=$id end=$endId');
    } catch (e) {
      debugPrint('Error canceling notification $id: $e');
    }
  }

  Future<void> cancelEventNotifications(
    String eventId, {
    List<int>? repeatDays,
  }) async {
    try {
      final baseId = eventId.hashCode;

      if (repeatDays != null && repeatDays.isNotEmpty) {
        for (final day in repeatDays) {
          await cancelNotification(baseId + day);
        }
      } else {
        await cancelNotification(baseId);
      }

      debugPrint('❌ Cancelled all notifs for event: $eventId');
    } catch (e) {
      debugPrint('Error canceling event notifications: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await flutterLocalNotificationsPlugin.cancelAll();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('scheduled_notifications');
      _invalidateCache();
      debugPrint('❌ All notifications cancelled');
    } catch (e) {
      debugPrint('Error canceling all notifications: $e');
    }
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications({
    bool useCache = true,
  }) async {
    if (useCache &&
        _pendingNotificationsCache != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!).inSeconds < 5) {
      return _pendingNotificationsCache!;
    }

    _pendingNotificationsCache =
        await flutterLocalNotificationsPlugin.pendingNotificationRequests();
    _cacheTime = DateTime.now();
    return _pendingNotificationsCache!;
  }

  Future<Map<String, dynamic>> getNotificationStatus() async {
    final scheduled = await _getScheduledNotificationsData();
    final pending = await getPendingNotifications(useCache: false);
    final now = DateTime.now();
    final upcoming =
        scheduled.where((n) => n.scheduledDate.isAfter(now)).length;

    return {
      'scheduled_count': upcoming,
      'pending_count': pending.length,
      'sync_needed': upcoming != pending.length,
    };
  }

  Future<void> ensureScheduledNotificationsExist() async {
    try {
      final notificationsData = await _getScheduledNotificationsData();
      final pendingIds = (await getPendingNotifications(useCache: false))
          .map((n) => n.id)
          .toSet();
      final now = DateTime.now();

      int rescheduled = 0;
      final stale = <int>[];

      for (final notif in notificationsData) {
        if (notif.scheduledDate.isAfter(now)) {
          if (!pendingIds.contains(notif.id)) {
            await _showNotificationInternal(notif);
            rescheduled++;
          }
        } else {
          stale.add(notif.id);
        }
      }

      for (final id in stale) {
        await _removeNotificationData(id);
      }

      if (rescheduled > 0 || stale.isNotEmpty) {
        _invalidateCache();
        debugPrint(
          '✅ Rescheduled=$rescheduled, removed ${stale.length} stale',
        );
      }
    } catch (e) {
      debugPrint('Error ensuring scheduled notifications: $e');
    }
  }

  static const _prefsKey = 'scheduled_notifications';

  Future<List<ScheduledNotificationData>> _getScheduledNotificationsData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_prefsKey) ?? [];

      return raw
          .map((item) {
            try {
              return ScheduledNotificationData.fromJson(jsonDecode(item));
            } catch (_) {
              return null;
            }
          })
          .whereType<ScheduledNotificationData>()
          .toList();
    } catch (e) {
      debugPrint('Error getting notification data: $e');
      return [];
    }
  }

  Future<ScheduledNotificationData?> _getNotificationDataById(int id) async {
    final all = await _getScheduledNotificationsData();
    try {
      return all.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveNotificationData(
    ScheduledNotificationData notif,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_prefsKey) ?? [];

      final updated = raw.where((item) {
        try {
          return ScheduledNotificationData.fromJson(jsonDecode(item)).id !=
              notif.id;
        } catch (_) {
          return false;
        }
      }).toList()
        ..add(jsonEncode(notif.toJson()));

      await prefs.setStringList(_prefsKey, updated);
    } catch (e) {
      debugPrint('Error saving notification data: $e');
    }
  }

  Future<void> _removeNotificationData(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_prefsKey) ?? [];

      final updated = raw.where((item) {
        try {
          return ScheduledNotificationData.fromJson(jsonDecode(item)).id != id;
        } catch (_) {
          return false;
        }
      }).toList();

      await prefs.setStringList(_prefsKey, updated);
    } catch (e) {
      debugPrint('Error removing notification data: $e');
    }
  }

  void _invalidateCache() {
    _pendingNotificationsCache = null;
    _cacheTime = null;
  }
}
