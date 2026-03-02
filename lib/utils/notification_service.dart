// lib/utils/notification_service.dart
//
// CONTRATO DE IDs (seguido aquí, en EventProvider y BackgroundService):
//
//   scheduleNotification(id, ...)      → registra con el ID exacto
//   scheduleEndNotification(id, ...)   → registra con (id + 10_000)  ← offset AQUÍ
//   cancelNotification(id)             → cancela id Y (id + 10_000)
//
// El caller SIEMPRE pasa el ID base:
//   Evento único      : eventId.hashCode
//   Repetitivo día N  : eventId.hashCode + N   (N = 1..7)
//
// ── ACCIONES EN NOTIFICACIONES ───────────────────────────────────────────────
//
// Para que "Completado" actualice la app, usamos un puerto de comunicación
// entre el handler de notificaciones (que corre sin contexto Flutter) y
// EventProvider (que es un singleton accesible directamente).
//
// Flujo:
//   Usuario pulsa acción → _onNotificationResponse(response)
//     → si mark_done: cancela notif + llama EventProvider().markEventDoneFromNotification(notifId)
//     → si snooze:    cancela notif + reprograma con mismo ID y título original

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
  // Guardamos el eventId para poder marcar el evento en EventProvider
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
      scheduledDate: DateTime.fromMillisecondsSinceEpoch(json['scheduledDate']),
      isEndNotification: json['isEndNotification'] ?? false,
      eventId: json['eventId'] as String?,
    );
  }
}


// CRÍTICO: debe ser una función TOP-LEVEL (no método de clase) y marcada con
// @pragma('vm:entry-point'). Android la invoca en un isolate separado cuando
// la app está cerrada o en background. No puede acceder a singletons de Flutter.
// Solo hace lo mínimo: guarda la acción en SharedPreferences para que la app
// la procese al abrirse (o usa el plugin directamente).
@pragma('vm:entry-point')
Future<void> notificationBackgroundHandler(NotificationResponse response) async {
  // En background/killed no podemos acceder a EventProvider ni a singletons de Flutter.
  // Guardamos la acción pendiente en SharedPreferences; la app la procesará al abrirse.
  final firedId = int.tryParse(response.payload ?? '');
  if (firedId == null) return;

  final actionId = response.actionId;
  if (actionId != 'mark_done' && actionId != 'snooze') return;

  try {
    final prefs = await SharedPreferences.getInstance();
    // Formato: "actionId:notifId"  p.ej. "mark_done:12345"
    final pending = prefs.getStringList('pending_notif_actions') ?? [];
    pending.add('$actionId:$firedId');
    await prefs.setStringList('pending_notif_actions', pending);
    debugPrint('📥 Background action queued: $actionId:$firedId');
  } catch (e) {
    debugPrint('Error queuing background action: $e');
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
      // CRÍTICO: registrar el handler de background.
      // Sin esto los botones no funcionan cuando la app está en background o cerrada.
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
    );

    tz.initializeTimeZones();
    await _createNotificationChannel();
    await _cleanOrphanNotifications();
  }

  // ── Handler de acciones ────────────────────────────────────────────────────
  //
  // IMPORTANTE: Este método se llama en el isolate PRINCIPAL cuando la app
  // está en primer plano o background (pero no killed). Aquí sí podemos
  // acceder al singleton EventProvider.
  void _onNotificationResponse(NotificationResponse response) async {
    // El payload siempre es el ID EXACTO con el que se registró la notificación
    final firedId = int.tryParse(response.payload ?? '');
    if (firedId == null) return;

    if (response.notificationResponseType ==
        NotificationResponseType.selectedNotification) {
      // Tap simple en la notificación — solo log
      debugPrint('🔔 Notification tapped: $firedId');
      return;
    }

    if (response.notificationResponseType !=
        NotificationResponseType.selectedNotificationAction) return;

    final actionId = response.actionId;

    if (actionId == 'mark_done') {
      await _handleMarkDone(firedId);
    } else if (actionId == 'snooze') {
      await _handleSnooze(firedId);
    }
  }

  Future<void> _handleMarkDone(int firedId) async {
    debugPrint('✔️ mark_done for notif id=$firedId');

    // 1. Cancelar SOLO esta notificación específica (no su par)
    //    Ya disparó, pero puede estar visible en el panel.
    await flutterLocalNotificationsPlugin.cancel(firedId);
    await _removeNotificationData(firedId);
    _invalidateCache();

    // 2. Recuperar datos guardados para obtener el eventId
    final stored = await _getNotificationDataById(firedId);
    if (stored?.eventId == null) {
      debugPrint('⚠️ mark_done: no eventId found for notif $firedId');
      return;
    }

    // 3. Delegar al EventProvider (singleton) para actualizar estado en la app
    //    Importamos aquí para evitar dependencia circular en el archivo
    //    (EventProvider importa NotificationService, no al revés).
    //    Usamos dynamic import via callback registrado.
    _markDoneCallback?.call(stored!.eventId!);
  }

  Future<void> _handleSnooze(int firedId) async {
    debugPrint('⏸️ snooze for notif id=$firedId');

    // 1. Recuperar datos originales ANTES de eliminar
    final stored = await _getNotificationDataById(firedId);

    // 2. Cancelar la notificación actual
    await flutterLocalNotificationsPlugin.cancel(firedId);
    await _removeNotificationData(firedId);
    _invalidateCache();

    // 3. Reprogramar con el mismo ID y título/body originales
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

    debugPrint('⏸️ Snoozed notif id=$firedId → rescheduled at $snoozeTime');
  }

  // ── Callback bridge con EventProvider ─────────────────────────────────────
  //
  // EventProvider registra este callback en su init() para que
  // NotificationService pueda notificarle sin importarlo directamente.
  //
  // Uso en EventProvider.init():
  //   NotificationService().registerMarkDoneCallback((eventId) {
  //     markEventDoneFromNotification(eventId);
  //   });
  void Function(String eventId)? _markDoneCallback;

  void registerMarkDoneCallback(void Function(String eventId) callback) {
    _markDoneCallback = callback;
    debugPrint('✅ NotificationService: markDone callback registered');
  }

  // ── Canal de notificaciones ────────────────────────────────────────────────
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

  // ── Limpieza de huérfanas ──────────────────────────────────────────────────
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

  // ── Schedule ───────────────────────────────────────────────────────────────

  /// Programa una notificación de inicio.
  /// [id] es el ID base. [eventId] se guarda para poder marcar el evento done.
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

  /// Programa una notificación de fin.
  /// Recibe el ID BASE — internamente registra con (id + 10_000).
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
      debugPrint('📅 Scheduled end notif baseId=$id → id=$endId at $scheduledDate');
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
              '⏸️ Posponer 5 min',
              showsUserInterface: false,
            ),
          ],
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: notif.id.toString(),
    );
  }


  // ── Métodos públicos para procesamiento de acciones background ────────────

  /// Devuelve los datos guardados de una notificación por su ID exacto.
  /// Usado por EventProvider al procesar acciones encoladas en background.
  Future<ScheduledNotificationData?> getNotificationDataById(int id) =>
      _getNotificationDataById(id);

  /// Cancela SOLO la notificación con este ID exacto (no su par).
  /// Usar cuando la notificación ya disparó y queremos descartarla del panel.
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

  /// Reprograma una notificación para 5 minutos después, conservando
  /// el título/body originales. Usado para el snooze desde background.
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

  // ── Cancel ─────────────────────────────────────────────────────────────────

  /// Cancela una notificación por su ID BASE.
  /// Cancela tanto el ID base (inicio) como (base + 10_000) (fin).
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

  /// Cancela todas las notificaciones de un evento dado su eventId string.
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

  // ── Pending & status ───────────────────────────────────────────────────────
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
    final upcoming = scheduled.where((n) => n.scheduledDate.isAfter(now)).length;
    return {
      'scheduled_count': upcoming,
      'pending_count': pending.length,
      'sync_needed': upcoming != pending.length,
    };
  }

  Future<void> ensureScheduledNotificationsExist() async {
    try {
      final notificationsData = await _getScheduledNotificationsData();
      final pendingIds =
          (await getPendingNotifications(useCache: false)).map((n) => n.id).toSet();
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
        debugPrint('✅ Rescheduled=$rescheduled, removed ${stale.length} stale');
      }
    } catch (e) {
      debugPrint('Error ensuring scheduled notifications: $e');
    }
  }

  // ── Persistence helpers ────────────────────────────────────────────────────
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

  Future<void> _saveNotificationData(ScheduledNotificationData notif) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_prefsKey) ?? [];

      // Reemplazar si ya existe el mismo ID
      final updated = raw.where((item) {
        try {
          return ScheduledNotificationData.fromJson(jsonDecode(item)).id != notif.id;
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