import 'package:flutter/material.dart';
import 'package:myapp/services/auth_service.dart';
import 'package:myapp/services/sync_service.dart';
import 'package:myapp/utils/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'day_screen.dart';
import '../models/event.dart';
import 'package:uuid/uuid.dart';

class HomeScreen extends StatefulWidget {
  final List<Event>? events;
  final Function(Event)? onAddEvent;
  final Function(int, Event)? onUpdateEvent;
  final Function(int, bool)? onDeleteEvent;
  final VoidCallback? onEventsUpdated; 

  const HomeScreen({
    super.key,
    this.events,
    this.onAddEvent,
    this.onUpdateEvent,
    this.onDeleteEvent,
    this.onEventsUpdated,
  });

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
      } else if (state.event == AuthChangeEvent.signedOut) {
        setState(() {
          allEvents = [];
          dailyEvents = [];
        });
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
          null,
        );

        // Notificación de finalización (solo si hay endTime)
        if (event.endTime != null) {
          NotificationService().scheduleEndNotification(
            event.id.hashCode + day,
            event.title,
            event.description ?? 'New Task',
            _calculateEndNotificationTime(day, event.endTime!),
            null,
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
        null,
      );

      // Notificación de finalización (solo si hay endTime)
      if (event.endTime != null) {
        NotificationService().scheduleEndNotification(
          event.id.hashCode,
          event.title,
          event.description ?? 'New Task',
          event.endTime!,
          null,
        );
      }
    }
  }

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
    final Set<String> seenIds = {};
    dailyEvents = allEvents.where((event) {
      final bool shouldInclude =
          isSameDay(event.startTime, selectedDate) ||
          event.repeatDays.contains(selectedDate.weekday);

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

  Future<void> _refreshEvents() async {
    await _loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        elevation: 0,
        title: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                getDayName(selectedDate.weekday),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                '${selectedDate.day} - ${selectedDate.month.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Indicador de conectividad 
          if (user != null) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: CircleAvatar(
                radius: 18,
                backgroundImage: user.userMetadata?['avatar_url'] != null
                    ? NetworkImage(user.userMetadata!['avatar_url'])
                    : null,
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                child: user.userMetadata?['avatar_url'] == null
                    ? Text(
                        user.userMetadata?['full_name']
                                ?.toString()
                                .substring(0, 1)
                                .toUpperCase() ??
                            user.email?.substring(0, 1).toUpperCase() ??
                            'U',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshEvents,
        child: DayScreen(
          day: selectedDate,
          events: dailyEvents,
          onAddEvent: addEvent,
          onUpdateEvent: updateEvent,
          onDeleteEvent: deleteEvent,
        ),
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