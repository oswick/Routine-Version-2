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
  final Map<DateTime, int> scheduledNotifications = {};

  factory NotificationService() => _notificationService;

  NotificationService._internal();

  Future<void> init() async {
    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidInitSettings);

    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.notificationResponseType == NotificationResponseType.selectedNotification &&
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

  // Save notification data to SharedPreferences for persistence
  Future<void> _saveNotificationData(ScheduledNotificationData notificationData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getStringList('scheduled_notifications') ?? [];
      
      // Check if this notification already exists
      final existingIndex = notificationsJson.indexWhere((item) {
        final existing = ScheduledNotificationData.fromJson(jsonDecode(item));
        return existing.id == notificationData.id;
      });
      
      if (existingIndex >= 0) {
        // Update existing
        notificationsJson[existingIndex] = jsonEncode(notificationData.toJson());
      } else {
        // Add new
        notificationsJson.add(jsonEncode(notificationData.toJson()));
      }
      
      await prefs.setStringList('scheduled_notifications', notificationsJson);
    } catch (e) {
      debugPrint('Error saving notification data: $e');
    }
  }

  // Remove notification data from SharedPreferences
  Future<void> _removeNotificationData(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getStringList('scheduled_notifications') ?? [];
      
      final filteredNotifications = notificationsJson.where((item) {
        final existing = ScheduledNotificationData.fromJson(jsonDecode(item));
        return existing.id != id;
      }).toList();
      
      await prefs.setStringList('scheduled_notifications', filteredNotifications);
    } catch (e) {
      debugPrint('Error removing notification data: $e');
    }
  }

  // Get all scheduled notifications from SharedPreferences
  Future<List<ScheduledNotificationData>> _getScheduledNotificationsData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getStringList('scheduled_notifications') ?? [];
      
      return notificationsJson
          .map((item) => ScheduledNotificationData.fromJson(jsonDecode(item)))
          .toList();
    } catch (e) {
      debugPrint('Error getting scheduled notifications data: $e');
      return [];
    }
  }

  // This method ensures that all scheduled notifications are properly set
  // It will be called periodically by the AlarmManager
  Future<void> ensureScheduledNotificationsExist() async {
    try {
      // Get all notification data that should be scheduled
      final notificationsData = await _getScheduledNotificationsData();
      
      // Get currently pending notifications
      final pendingNotifications = await getPendingNotifications();
      final pendingIds = pendingNotifications.map((n) => n.id).toSet();
      
      // For each notification data, check if it's already scheduled
      for (final notificationData in notificationsData) {
        // Only schedule notifications in the future
        if (notificationData.scheduledDate.isAfter(DateTime.now())) {
          // If not already scheduled, schedule it
          if (!pendingIds.contains(notificationData.id)) {
            print('Rescheduling notification ${notificationData.id} from background');
            
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
                ),
              ),
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              payload: notificationData.id.toString(),
            );
          }
        } else {
          // Clean up past notifications
          await _removeNotificationData(notificationData.id);
        }
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
      // Only schedule if it's in the future
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
              // This flag allows notifications to be shown when the app is closed
              fullScreenIntent: true,
            ),
          ),
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // Use exactAllowWhileIdle
          payload: id.toString(),
        );
        
        // Save notification data for persistence
        await _saveNotificationData(ScheduledNotificationData(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduledDate,
        ));
        
        // opcional: log para depurar
        debugPrint('📅 Notificación programada ($id) para $scheduledDate');
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

  // Nuevo método para programar la notificación de finalización de un evento
  Future<void> scheduleEndNotification(
    int id,
    String title,
    String body,
    DateTime scheduledDate,
    BuildContext? context,
  ) async {
    try {
      // Utilizamos un ID diferente para la notificación de finalización
      // sumando un valor fijo para diferenciarla
      final endNotificationId = id + 10000;
      
      // Only schedule if it's in the future
      if (scheduledDate.isAfter(DateTime.now())) {
        await flutterLocalNotificationsPlugin.zonedSchedule(
          endNotificationId,
          "Evento finalizado: $title",
          "El evento $title ha terminado",
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
              // This flag allows notifications to be shown when the app is closed
              fullScreenIntent: true,
            ),
          ),
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // Use exactAllowWhileIdle
          payload: id.toString(),
        );
        
        // Save notification data for persistence
        await _saveNotificationData(ScheduledNotificationData(
          id: endNotificationId,
          title: "Evento finalizado: $title",
          body: "El evento $title ha terminado",
          scheduledDate: scheduledDate,
          isEndNotification: true,
        ));
        
        // optional: log for debugging
        debugPrint('📅 Notificación de finalización programada ($endNotificationId) para $scheduledDate');
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
    
    // Cancelar también la notificación de finalización
    final endNotificationId = id + 10000;
    await flutterLocalNotificationsPlugin.cancel(endNotificationId);
    await _removeNotificationData(endNotificationId);
    
    debugPrint('❌ Notificación cancelada ($id)');
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
    
    // Clear stored notification data
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('scheduled_notifications');
    
    scheduledNotifications.clear();
  }
}
