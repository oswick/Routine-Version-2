import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

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
      debugPrint('Error requesting notification permission: \$e');
    }
  }

  Future<void> scheduleNotification(
    int id,
    String title,
    String body,
    DateTime scheduledDate,
    BuildContext context,
  ) async {
    try {
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
          ),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
        androidScheduleMode: AndroidScheduleMode.exact,
        payload: id.toString(),
      );
      // opcional: log para depurar
      debugPrint('📅 Notificación programada ($id) para $scheduledDate');
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scheduling notification: $e')),
      );
    }
  }

  // Nuevo método para programar la notificación de finalización de un evento
  Future<void> scheduleEndNotification(
    int id,
    String title,
    String body,
    DateTime scheduledDate,
    BuildContext context,
  ) async {
    try {
      // Utilizamos un ID diferente para la notificación de finalización
      // sumando un valor fijo para diferenciarla
      final endNotificationId = id + 10000;
      
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
          ),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
        androidScheduleMode: AndroidScheduleMode.exact,
        payload: id.toString(),
      );
      // opcional: log para depurar
      debugPrint('📅 Notificación de finalización programada ($endNotificationId) para $scheduledDate');
    } catch (e) {
      debugPrint('Error scheduling end notification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scheduling end notification: $e')),
      );
    }
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
    // Cancelar también la notificación de finalización
    await flutterLocalNotificationsPlugin.cancel(id + 10000);
    debugPrint('❌ Notificación cancelada ($id)');
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
    scheduledNotifications.clear();
  }
}