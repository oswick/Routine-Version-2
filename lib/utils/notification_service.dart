// lib/utils/notification_service.dart - VERSIÓN COMPLETA OPTIMIZADA
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

  // 🆕 NUEVO: Cache de notificaciones pendientes
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
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.notificationResponseType ==
                NotificationResponseType.selectedNotification &&
            response.payload != null) {
          // Handle notification tap logic here
        }
      },
    );
    tz.initializeTimeZones();
    await _createNotificationChannel();
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

  // 🆕 OPTIMIZADO: Batch save de notificaciones
  Future<void> _batchSaveNotificationData(
    List<ScheduledNotificationData> notificationsList,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson =
          prefs.getStringList('scheduled_notifications') ?? [];

      final notificationsMap = {
        for (var item in notificationsJson)
          ScheduledNotificationData.fromJson(jsonDecode(item)).id: item
      };

      // Actualizar o agregar nuevas
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

  // 🆕 OPTIMIZADO: Cache de notificaciones pendientes
  Future<List<PendingNotificationRequest>> getPendingNotifications({
    bool useCache = true,
  }) async {
    // Usar cache si es válido (menos de 5 segundos)
    if (useCache && 
        _pendingNotificationsCache != null && 
        _cacheTime != null) {
      final timeDiff = DateTime.now().difference(_cacheTime!);
      if (timeDiff.inSeconds < 5) {
        return _pendingNotificationsCache!;
      }
    }

    // Actualizar cache
    _pendingNotificationsCache = 
        await flutterLocalNotificationsPlugin.pendingNotificationRequests();
    _cacheTime = DateTime.now();
    
    return _pendingNotificationsCache!;
  }

  // 🆕 NUEVO: Invalidar cache
  void _invalidateCache() {
    _pendingNotificationsCache = null;
    _cacheTime = null;
  }

  // 🆕 OPTIMIZADO: Proceso batch para reprogramación
  Future<void> ensureScheduledNotificationsExist() async {
    try {
      final notificationsData = await _getScheduledNotificationsData();
      final pendingNotifications = await getPendingNotifications();
      final pendingIds = pendingNotifications.map((n) => n.id).toSet();
      
      int rescheduledCount = 0;
      final now = DateTime.now();
      
      // 🆕 Procesar en lotes
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
      
      // Reprogramar en lote
      for (final notificationData in toReschedule) {
        print('🔔 Rescheduling notification ${notificationData.id}');
        
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
              playSound: true,
              fullScreenIntent: true,
              category: AndroidNotificationCategory.alarm,
              visibility: NotificationVisibility.public,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: notificationData.id.toString(),
        );
        rescheduledCount++;
      }
      
      // Limpiar antiguas en lote
      for (final id in toRemove) {
        await _removeNotificationData(id);
      }
      
      if (rescheduledCount > 0 || toRemove.isNotEmpty) {
        _invalidateCache(); // Invalidar cache después de cambios
        print('✅ Rescheduled $rescheduledCount, removed ${toRemove.length} old notifications');
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
        await flutterLocalNotificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          tz.TZDateTime.from(scheduledDate, tz.local),
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
              category: AndroidNotificationCategory.alarm,
              visibility: NotificationVisibility.public,
              showWhen: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: id.toString(),
        );

        await _saveNotificationData(
          ScheduledNotificationData(
            id: id,
            title: title,
            body: body,
            scheduledDate: scheduledDate,
          ),
        );

        _invalidateCache();
        debugPrint('📅 Scheduled notification ($id) for $scheduledDate');
      }
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
      if (context != null) {
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
        await flutterLocalNotificationsPlugin.zonedSchedule(
          endNotificationId,
          "Event finished: $title",
          "The event $title has ended",
          tz.TZDateTime.from(scheduledDate, tz.local),
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
              category: AndroidNotificationCategory.alarm,
              visibility: NotificationVisibility.public,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: id.toString(),
        );

        await _saveNotificationData(
          ScheduledNotificationData(
            id: endNotificationId,
            title: "Event finished: $title",
            body: "The event $title has ended",
            scheduledDate: scheduledDate,
            isEndNotification: true,
          ),
        );

        _invalidateCache();
        debugPrint(
          '📅 Scheduled end notification ($endNotificationId) for $scheduledDate',
        );
      }
    } catch (e) {
      debugPrint('Error scheduling end notification: $e');
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scheduling end notification: $e')),
        );
      }
    }
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
    await _removeNotificationData(id);

    final endNotificationId = id + 10000;
    await flutterLocalNotificationsPlugin.cancel(endNotificationId);
    await _removeNotificationData(endNotificationId);

    _invalidateCache();
    debugPrint('❌ Notification canceled ($id)');
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('scheduled_notifications');

    _invalidateCache();
  }

  Future<Map<String, dynamic>> getNotificationStatus() async {
    final scheduled = await _getScheduledNotificationsData();
    final pending = await getPendingNotifications(useCache: false);
    final now = DateTime.now();
    
    final upcomingScheduled = scheduled.where((n) => n.scheduledDate.isAfter(now)).length;
    final pendingCount = pending.length;
    
    return {
      'scheduled_count': upcomingScheduled,
      'pending_count': pendingCount,
      'sync_needed': upcomingScheduled != pendingCount,
    };
  }
}