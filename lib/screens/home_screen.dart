import 'package:flutter/material.dart';
import 'package:myapp/screens/calendar_screen.dart';
import 'package:myapp/services/auth_service.dart';
import 'package:myapp/services/sync_service.dart';
import 'package:myapp/utils/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'day_screen.dart';
import '../models/event.dart';
import 'package:uuid/uuid.dart'; // Importa la librería UUID

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final SyncService _syncService = SyncService();
  List<Event> allEvents = [];
  List<Event> dailyEvents = [];
  DateTime selectedDate = DateTime.now();
  final Uuid uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _loadEvents();
    NotificationService().init();
    NotificationService().requestNotificationPermission();
    _filterDailyEvents();
    _initializeServices();

    // Escuchar cambios de autenticación
    _authService.authStateChanges.listen((state) {
      if (state.event == AuthChangeEvent.signedIn) {
        _loadEvents();
      }
    });
  }

  Future<void> _initializeServices() async {
    await _syncService.init();
    await _loadEvents();
  }

  Future<void> _loadEvents() async {
    final events = await _syncService.getEvents();
    setState(() {
      allEvents = events;
      _filterDailyEvents();
    });
  }

  void addEvent(Event event) async {
    final userId = _authService.currentUserId;
    if (userId == null) return;

    final newEvent = event.copyWith(id: uuid.v4(), userId: userId);

    await _syncService.saveEvent(newEvent);
    await _loadEvents();

    if (!newEvent.isCompleted) {
      _scheduleEventNotifications(newEvent);
    }
  }

  void updateEvent(int index, Event event) async {
    final oldEvent = allEvents[index];
    await _syncService.saveEvent(event);
    await _loadEvents();

    _cancelAllEventNotifications(oldEvent);
    if (!event.isCompleted) {
      _scheduleEventNotifications(event);
    }
  }

  void _cancelAllEventNotifications(Event event) {
    // Cancelar la notificación base del evento
    NotificationService().flutterLocalNotificationsPlugin.cancel(
      event.id.hashCode,
    );
    // Cancelar la notificación de finalización del evento
    NotificationService().flutterLocalNotificationsPlugin.cancel(
      event.id.hashCode + 10000,
    );

    // Si es un evento repetitivo, cancelar todas las notificaciones de los días repetidos
    if (event.repeatDays.isNotEmpty) {
      for (int day in event.repeatDays) {
        // Cancelar notificación de inicio
        NotificationService().flutterLocalNotificationsPlugin.cancel(
          event.id.hashCode + day,
        );
        // Cancelar notificación de finalización
        NotificationService().flutterLocalNotificationsPlugin.cancel(
          event.id.hashCode + day + 10000,
        );
      }
    }

    // Cancelar cualquier notificación específica del día
    NotificationService().flutterLocalNotificationsPlugin.cancel(
      event.id.hashCode + DateTime.now().weekday,
    );
    // Cancelar cualquier notificación de finalización específica del día
    NotificationService().flutterLocalNotificationsPlugin.cancel(
      event.id.hashCode + DateTime.now().weekday + 10000,
    );
  }

  void deleteEvent(int index, bool allDays) async {
    final event = allEvents[index];
    _cancelAllEventNotifications(event);

    if (allDays) {
      await _syncService.deleteAllEventInstances(event.id);
    } else {
      await _syncService.deleteEvent(event.id);
    }

    await _loadEvents();
  }

  void _scheduleEventNotifications(Event event) {
    if (event.repeatDays.isNotEmpty) {
      for (int day in event.repeatDays) {
        // Notificación de inicio
        NotificationService().scheduleNotification(
          event.id.hashCode + day,
          event.title,
          event.description ?? 'New Task',
          _calculateNotificationTime(day, event.startTime),
          null, // Pass null for context when called from background
        );

        // Notificación de finalización (solo si hay endTime)
        if (event.endTime != null) {
          NotificationService().scheduleEndNotification(
            event.id.hashCode + day,
            event.title,
            event.description ?? 'New Task',
            _calculateEndNotificationTime(day, event.endTime!),
            null, // Pass null for context when called from background
          );
        }
      }
    } else {
      // Notificación de inicio
      NotificationService().scheduleNotification(
        event.id.hashCode,
        event.title,
        event.description ?? 'New Task',
        event.startTime,
        null, // Pass null for context when called from background
      );

      // Notificación de finalización (solo si hay endTime)
      if (event.endTime != null) {
        NotificationService().scheduleEndNotification(
          event.id.hashCode,
          event.title,
          event.description ?? 'New Task',
          event.endTime!,
          null, // Pass null for context when called from background
        );
      }
    }
  }

  // Método para calcular el tiempo de notificación de finalización para eventos recurrentes
  DateTime _calculateEndNotificationTime(int day, DateTime endTime) {
    DateTime now = DateTime.now();
    int daysUntilNext = (day - now.weekday + 7) % 7;
    DateTime nextNotificationDate = now.add(Duration(days: daysUntilNext));
    return DateTime(
      nextNotificationDate.year,
      nextNotificationDate.month,
      nextNotificationDate.day,
      endTime.hour,
      endTime.minute,
    );
  }

  void _filterDailyEvents() {
    final Set<String> seenIds = {}; // Para rastrear IDs únicos
    dailyEvents = allEvents.where((event) {
      // Verificar si el evento es para el día actual o repetido
      final bool shouldInclude =
          isSameDay(event.startTime, selectedDate) ||
          event.repeatDays.contains(selectedDate.weekday);

      // Solo incluir el evento si no hemos visto su ID antes
      if (shouldInclude && !seenIds.contains(event.id)) {
        seenIds.add(event.id);
        return true;
      }
      return false;
    }).toList();
  }

  DateTime _calculateNotificationTime(int day, DateTime startTime) {
    DateTime now = DateTime.now();
    int daysUntilNext = (day - now.weekday + 7) % 7;
    DateTime nextNotificationDate = now.add(Duration(days: daysUntilNext));
    return DateTime(
      nextNotificationDate.year,
      nextNotificationDate.month,
      nextNotificationDate.day,
      startTime.hour,
      startTime.minute,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              getDayName(selectedDate.weekday),
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
            Text(
              '${selectedDate.day} - ${selectedDate.month.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _authService.currentUser != null ? Icons.logout : Icons.login,
            ),
            onPressed: () async {
              if (_authService.currentUser != null) {
                await _authService.signOut();
              } else {
                await _authService.signInWithGoogle();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MonthlyCalendarScreen(
                    events: allEvents,
                    onAddEvent: addEvent,
                    onUpdateEvent: updateEvent,
                    onDeleteEvent: deleteEvent,
                    fromHomeScreen: true, // Pasamos deleteEvent correctamente
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: DayScreen(
        day: selectedDate,
        events: dailyEvents,
        onAddEvent: addEvent,
        onUpdateEvent: updateEvent,
        onDeleteEvent: deleteEvent, // Pasamos deleteEvent correctamente
      ),
    );
  }

  String getDayName(int dayOfWeek) {
    switch (dayOfWeek) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return '';
    }
  }
}
