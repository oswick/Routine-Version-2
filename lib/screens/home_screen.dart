import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:myapp/screens/calendar_screen.dart';
import 'package:myapp/utils/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  List<Event> allEvents = [];
  List<Event> dailyEvents = [];
  DateTime selectedDate = DateTime.now();
  final Uuid uuid = const Uuid(); // Inicializa UUID

  @override
  void initState() {
    super.initState();
    _loadEvents();
    NotificationService().init();
    NotificationService().requestNotificationPermission();
    _filterDailyEvents();
  }

  void addEvent(Event event) {
    setState(() {
      final newEvent = event.copyWith(id: uuid.v4()); // Asigna un ID único
      allEvents.add(newEvent);
      if (!newEvent.isCompleted) {
        _scheduleEventNotifications(newEvent);
      }
      _filterDailyEvents();
      _saveEvents();
    });
  }

  void updateEvent(int index, Event event) {
    setState(() {
      final oldEvent = allEvents[index];
      allEvents[index] = event;

      // Usar el nuevo método _cancelAllEventNotifications en lugar de _cancelEventNotifications
      _cancelAllEventNotifications(oldEvent);

      if (!event.isCompleted) {
        _scheduleEventNotifications(event);
      }

      _filterDailyEvents();
      _saveEvents();
    });
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

  void deleteEvent(int index, bool allDays) {
    setState(() {
      final event = allEvents[index];

      // Cancelar todas las notificaciones relacionadas con el evento
      _cancelAllEventNotifications(event);

      if (allDays) {
        // Eliminar todos los eventos con el mismo ID
        allEvents.removeWhere((e) => e.id == event.id);
      } else {
        // Eliminar solo el evento específico
        allEvents.removeAt(index);
      }

      _filterDailyEvents();
      _saveEvents();
    });
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
          context,
        );

        // Notificación de finalización (solo si hay endTime)
        if (event.endTime != null) {
          NotificationService().scheduleEndNotification(
            event.id.hashCode + day,
            event.title,
            event.description ?? 'New Task',
            _calculateEndNotificationTime(day, event.endTime!),
            context,
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
        context,
      );

      // Notificación de finalización (solo si hay endTime)
      if (event.endTime != null) {
        NotificationService().scheduleEndNotification(
          event.id.hashCode,
          event.title,
          event.description ?? 'New Task',
          event.endTime!,
          context,
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
    dailyEvents =
        allEvents.where((event) {
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

  Future<void> _loadEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final eventsData = prefs.getStringList('events');
      if (eventsData != null) {
        final loadedEvents =
            eventsData.map((eventData) {
              final eventMap = jsonDecode(eventData);
              return Event.fromJson(eventMap);
            }).toList();

        // Eliminar duplicados basados en el ID
        final uniqueEvents = <Event>[];
        final seenIds = <String>{};
        for (final event in loadedEvents) {
          if (!seenIds.contains(event.id)) {
            uniqueEvents.add(event);
            seenIds.add(event.id);
          }
        }

        setState(() {
          allEvents = uniqueEvents;
          _filterDailyEvents();
        });

        // Imprimir IDs para verificación
        allEvents.forEach((event) {
          print('Event ID: ${event.id}');
        });
      }
    } catch (e) {
      print('Error loading events: $e');
    }
  }

  Future<void> _saveEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final eventsData =
          allEvents.map((event) {
            return jsonEncode(event.toJson());
          }).toList();
      prefs.setStringList('events', eventsData);
    } catch (e) {
      print('Error saving events: $e');
    }
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
            icon: const Icon(Icons.calendar_today),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => MonthlyCalendarScreen(
                        events: allEvents,
                        onAddEvent: addEvent,
                        onUpdateEvent: updateEvent,
                        onDeleteEvent: deleteEvent,
                        fromHomeScreen:
                            true, // Pasamos deleteEvent correctamente
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
