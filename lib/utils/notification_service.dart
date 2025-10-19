// lib/utils/notification_service.dart - VERSIÓN CORREGIDA
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
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

  ScheduledNotificationData({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledDate,
    this.isEndNotification = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'scheduledDate': scheduledDate.millisecondsSinceEpoch,
      'isEndNotification': isEndNotification,
    };
  }

  factory ScheduledNotificationData.fromJson(Map<String, dynamic> json) {
    return ScheduledNotificationData(
      id: json['id'],
      title: json['title'],
      body: json['body'],
      scheduledDate: DateTime.fromMillisecondsSinceEpoch(json['scheduledDate']),
      isEndNotification: json['isEndNotification'] ?? false,
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
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (response.notificationResponseType ==
            NotificationResponseType.selectedNotification) {
          if (response.payload != null) {
            debugPrint("🔔 Notification tapped: ${response.payload}");
          }
        } else if (response.notificationResponseType ==
            NotificationResponseType.selectedNotificationAction) {
          final actionId = response.actionId;
          final payload = response.payload;
          final notifId = int.tryParse(payload ?? '');

          if (notifId != null) {
            if (actionId == 'mark_done') {
              await cancelNotification(notifId);
              debugPrint("✔️ Notification $notifId marked as completed");
            } else if (actionId == 'snooze') {
              final newTime = DateTime.now().add(const Duration(minutes: 2));
              await scheduleNotification(
                notifId,
                "⏰ Reprogramado",
                "Recordatorio pospuesto 2 min",
                newTime,
                null,
              );
              debugPrint("⏸️ Notification $notifId snoozed for 2 minutes");
            }
          }
        }
      },
    );

    tz.initializeTimeZones();
    await _createNotificationChannel();

    // 🆕 NUEVO: Limpiar notificaciones huérfanas al iniciar
    await _cleanOrphanNotifications();
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
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  Future<void> requestNotificationPermission() async {
    try {
      if (Platform.isAndroid) {
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }
  }

  // 🆕 NUEVO: Limpiar notificaciones sin datos guardados
  Future<void> _cleanOrphanNotifications() async {
    try {
      final pending = await flutterLocalNotificationsPlugin
          .pendingNotificationRequests();
      final saved = await _getScheduledNotificationsData();

      final savedIds = saved.map((n) => n.id).toSet();
      int canceledCount = 0;

      for (final pendingNotif in pending) {
        if (!savedIds.contains(pendingNotif.id)) {
          await flutterLocalNotificationsPlugin.cancel(pendingNotif.id);
          canceledCount++;
          debugPrint('🧹 Canceled orphan notification: ${pendingNotif.id}');
        }
      }

      if (canceledCount > 0) {
        debugPrint('🧹 Cleaned $canceledCount orphan notifications');
        _invalidateCache();
      }
    } catch (e) {
      debugPrint('Error cleaning orphan notifications: $e');
    }
  }

  Future<void> _batchSaveNotificationData(
    List<ScheduledNotificationData> notificationsList,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson =
          prefs.getStringList('scheduled_notifications') ?? [];

      final notificationsMap = {
        for (var item in notificationsJson)
          ScheduledNotificationData.fromJson(jsonDecode(item)).id: item,
      };

      for (var notification in notificationsList) {
        notificationsMap[notification.id] = jsonEncode(notification.toJson());
      }

      await prefs.setStringList(
        'scheduled_notifications',
        notificationsMap.values.toList(),
      );
    } catch (e) {
      debugPrint('Error batch saving notification data: $e');
    }
  }

  Future<void> _saveNotificationData(
    ScheduledNotificationData notificationData,
  ) async {
    await _batchSaveNotificationData([notificationData]);
  }

  Future<void> _removeNotificationData(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson =
          prefs.getStringList('scheduled_notifications') ?? [];

      final filteredNotifications = notificationsJson.where((item) {
        final existing = ScheduledNotificationData.fromJson(jsonDecode(item));
        return existing.id != id;
      }).toList();

      await prefs.setStringList(
        'scheduled_notifications',
        filteredNotifications,
      );
    } catch (e) {
      debugPrint('Error removing notification data: $e');
    }
  }

  Future<List<ScheduledNotificationData>>
  _getScheduledNotificationsData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson =
          prefs.getStringList('scheduled_notifications') ?? [];

      return notificationsJson
          .map((item) => ScheduledNotificationData.fromJson(jsonDecode(item)))
          .toList();
    } catch (e) {
      debugPrint('Error getting scheduled notifications data: $e');
      return [];
    }
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications({
    bool useCache = true,
  }) async {
    if (useCache && _pendingNotificationsCache != null && _cacheTime != null) {
      final timeDiff = DateTime.now().difference(_cacheTime!);
      if (timeDiff.inSeconds < 5) {
        return _pendingNotificationsCache!;
      }
    }

    _pendingNotificationsCache = await flutterLocalNotificationsPlugin
        .pendingNotificationRequests();
    _cacheTime = DateTime.now();

    return _pendingNotificationsCache!;
  }

  void _invalidateCache() {
    _pendingNotificationsCache = null;
    _cacheTime = null;
  }

  Future<void> ensureScheduledNotificationsExist() async {
    try {
      final notificationsData = await _getScheduledNotificationsData();
      final pendingNotifications = await getPendingNotifications(
        useCache: false,
      );
      final pendingIds = pendingNotifications.map((n) => n.id).toSet();

      int rescheduledCount = 0;
      final now = DateTime.now();

      final toReschedule = <ScheduledNotificationData>[];
      final toRemove = <int>[];

      for (final notificationData in notificationsData) {
        if (notificationData.scheduledDate.isAfter(now)) {
          if (!pendingIds.contains(notificationData.id)) {
            toReschedule.add(notificationData);
          }
        } else {
          toRemove.add(notificationData.id);
        }
      }

      for (final notificationData in toReschedule) {
        await _showNotificationInternal(notificationData);
        rescheduledCount++;
      }

      for (final id in toRemove) {
        await _removeNotificationData(id);
      }

      if (rescheduledCount > 0 || toRemove.isNotEmpty) {
        _invalidateCache();
        debugPrint(
          '✅ Rescheduled $rescheduledCount, removed ${toRemove.length}',
        );
      }
    } catch (e) {
      debugPrint('Error ensuring scheduled notifications: $e');
    }
  }

  Future<void> scheduleNotification(
    int id,
    String title,
    String body,
    DateTime scheduledDate,
    BuildContext? context,
  ) async {
    try {
      if (scheduledDate.isAfter(DateTime.now())) {
        final notif = ScheduledNotificationData(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduledDate,
        );
        await _showNotificationInternal(notif);
        await _saveNotificationData(notif);

        _invalidateCache();
        debugPrint('📅 Scheduled notification ($id) for $scheduledDate');
      }
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scheduling notification: $e')),
        );
      }
    }
  }

  Future<void> scheduleEndNotification(
    int id,
    String title,
    String body,
    DateTime scheduledDate,
    BuildContext? context,
  ) async {
    try {
      final endNotificationId = id + 10000;

      if (scheduledDate.isAfter(DateTime.now())) {
        final notif = ScheduledNotificationData(
          id: endNotificationId,
          title: "Event finished: $title",
          body: "The event $title has ended",
          scheduledDate: scheduledDate,
          isEndNotification: true,
        );
        await _showNotificationInternal(notif);
        await _saveNotificationData(notif);

        _invalidateCache();
        debugPrint(
          '📅 Scheduled end notification ($endNotificationId) for $scheduledDate',
        );
      }
    } catch (e) {
      debugPrint('Error scheduling end notification: $e');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scheduling end notification: $e')),
        );
      }
    }
  }

  Future<void> _showNotificationInternal(
    ScheduledNotificationData notificationData,
  ) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      notificationData.id,
      notificationData.title,
      notificationData.body,
      tz.TZDateTime.from(notificationData.scheduledDate, tz.local),
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
          fullScreenIntent: true,
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.public,
          showWhen: true,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              'mark_done',
              '✔️ Completado',
              showsUserInterface: false,
            ),
            AndroidNotificationAction(
              'snooze',
              '⏸️ Posponer 2 min',
              showsUserInterface: false,
            ),
          ],
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: notificationData.id.toString(),
    );
  }

  // 🆕 CORREGIDO: Cancelar notificación con limpieza completa
  Future<void> cancelNotification(int id) async {
    try {
      // 1. Cancelar notificación principal
      await flutterLocalNotificationsPlugin.cancel(id);
      await _removeNotificationData(id);
      debugPrint('❌ Canceled notification: $id');

      // 2. Cancelar notificación de finalización
      final endNotificationId = id + 10000;
      await flutterLocalNotificationsPlugin.cancel(endNotificationId);
      await _removeNotificationData(endNotificationId);
      debugPrint('❌ Canceled end notification: $endNotificationId');

      _invalidateCache();
    } catch (e) {
      debugPrint('Error canceling notification $id: $e');
    }
  }

  // 🆕 NUEVO: Cancelar notificaciones por hash de evento
  Future<void> cancelEventNotifications(
    String eventId, {
    List<int>? repeatDays,
  }) async {
    try {
      final baseId = eventId.hashCode;

      // Cancelar notificación principal
      await cancelNotification(baseId);

      // Si tiene días de repetición, cancelar esas también
      if (repeatDays != null && repeatDays.isNotEmpty) {
        for (int day in repeatDays) {
          final dayNotifId = baseId + day;
          await cancelNotification(dayNotifId);
        }
      }

      debugPrint('❌ Canceled all notifications for event: $eventId');
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
      debugPrint('❌ All notifications canceled');
    } catch (e) {
      debugPrint('Error canceling all notifications: $e');
    }
  }

  Future<Map<String, dynamic>> getNotificationStatus() async {
    final scheduled = await _getScheduledNotificationsData();
    final pending = await getPendingNotifications(useCache: false);
    final now = DateTime.now();

    final upcomingScheduled = scheduled
        .where((n) => n.scheduledDate.isAfter(now))
        .length;
    final pendingCount = pending.length;

    return {
      'scheduled_count': upcomingScheduled,
      'pending_count': pendingCount,
      'sync_needed': upcomingScheduled != pendingCount,
    };
  }
}
