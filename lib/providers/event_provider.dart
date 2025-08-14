// lib/providers/event_provider.dart - Versión corregida
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event.dart';
import '../services/sync_service.dart';
import '../services/auth_service.dart';
import '../utils/notification_service.dart';
import 'package:uuid/uuid.dart';

class EventProvider extends ChangeNotifier {
  static final EventProvider _instance = EventProvider._internal();
  factory EventProvider() => _instance;
  EventProvider._internal();

  final SyncService _syncService = SyncService();
  final AuthService _authService = AuthService();
  final Uuid _uuid = const Uuid();

  List<Event> _events = [];
  bool _isLoading = false;
  String? _error;

  // Streams para actualizaciones en tiempo real
  final StreamController<List<Event>> _eventsController =
      StreamController<List<Event>>.broadcast();

  // Getters
  List<Event> get events => List.unmodifiable(_events);
  bool get isLoading => _isLoading;
  String? get error => _error;
  Stream<List<Event>> get eventsStream => _eventsController.stream;

  // Inicializar el provider
  Future<void> init() async {
    await _syncService.init();
    await loadEvents();

    // Escuchar cambios de autenticación
    _authService.authStateChanges.listen((state) {
      if (state.event == AuthChangeEvent.signedIn) {
        loadEvents();
      } else if (state.event == AuthChangeEvent.signedOut) {
        _clearEvents();
      }
    });
  }

  Future<void> loadEvents() async {
    _setLoading(true);
    try {
      final loadedEvents = await _syncService.getEvents();
      _updateEvents(loadedEvents);
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading events: $e');
    } finally {
      _setLoading(false);
      notifyListeners(); // Notificar a los oyentes
    }
  }

  // Agregar evento
  Future<void> addEvent(Event event) async {
    try {
      final userId = _authService.currentUserId ?? 'local_user';
      final newEvent = event.copyWith(
        id: _uuid.v4(),
        userId: userId,
        needsSync: _authService.isAuthenticated,
      );

      // Optimistic update - agregar inmediatamente a la UI
      _events.add(newEvent);
      _notifyChanges();

      // Guardar en el backend
      await _syncService.saveEvent(newEvent);

      // Programar notificaciones
      if (!newEvent.isCompleted) {
        _scheduleEventNotifications(newEvent);
      }
    } catch (e) {
      // En caso de error, recargar para mantener consistencia
      await loadEvents();
      _error = e.toString();
      rethrow;
    }
  }

  // MÉTODO CORREGIDO: Actualizar evento sin recargar toda la lista
  Future<void> updateEvent(Event updatedEvent) async {
    try {
      final index = _events.indexWhere((e) => e.id == updatedEvent.id);
      if (index == -1) return;

      final oldEvent = _events[index];

      // Optimistic update - actualizar solo el evento específico
      _events[index] = updatedEvent;
      _notifyChanges();

      // Guardar en el backend en el fondo
      _syncService.saveEvent(updatedEvent).catchError((e) {
        debugPrint('Error saving event to backend: $e');
        // En caso de error, restaurar el evento anterior
        if (mounted && index < _events.length) {
          _events[index] = oldEvent;
          _notifyChanges();
        }
      });

      // Actualizar notificaciones
      _cancelAllEventNotifications(oldEvent);
      if (!updatedEvent.isCompleted) {
        _scheduleEventNotifications(updatedEvent);
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error updating event: $e');
    }
  }

  // Eliminar evento
  Future<void> deleteEvent(String eventId, {bool deleteAll = false}) async {
    try {
      final eventIndex = _events.indexWhere((e) => e.id == eventId);
      if (eventIndex == -1) return;

      final event = _events[eventIndex];

      // Optimistic update
      _events.removeAt(eventIndex);
      _notifyChanges();

      // Cancelar notificaciones
      _cancelAllEventNotifications(event);

      // Eliminar del backend
      if (deleteAll) {
        await _syncService.deleteAllEventInstances(eventId);
      } else {
        await _syncService.deleteEvent(eventId);
      }
    } catch (e) {
      await loadEvents();
      _error = e.toString();
      rethrow;
    }
  }

  // Obtener eventos para un día específico
  List<Event> getEventsForDay(DateTime day) {
    final Set<String> seenIds = {};
    return _events.where((event) {
      // Evitar duplicados
      if (seenIds.contains(event.id)) {
        return false;
      }

      bool shouldInclude = false;

      // Para eventos repetitivos
      if (event.repeatDays.isNotEmpty) {
        final eventCreationDate = DateTime(
          event.startTime.year,
          event.startTime.month,
          event.startTime.day,
        );
        final queryDate = DateTime(day.year, day.month, day.day);

        shouldInclude =
            event.repeatDays.contains(day.weekday) &&
            (queryDate.isAtSameMomentAs(eventCreationDate) ||
                queryDate.isAfter(eventCreationDate));
      }
      // Para eventos únicos (no repetitivos)
      else {
        shouldInclude = _isSameDay(event.startTime, day);
      }

      if (shouldInclude) {
        seenIds.add(event.id);
        return true;
      }
      return false;
    }).toList();
  }

  // Métodos privados
  void _updateEvents(List<Event> newEvents) {
    _events = newEvents;
    _notifyChanges();
  }

  void _clearEvents() {
    _events = [];
    _notifyChanges();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _notifyChanges() {
    notifyListeners();
    _eventsController.add(_events);
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // Helper para verificar si el provider está montado
  bool get mounted => !_eventsController.isClosed;

  // Métodos de notificaciones
  void _scheduleEventNotifications(Event event) {
    if (event.repeatDays.isNotEmpty) {
      for (int day in event.repeatDays) {
        NotificationService().scheduleNotification(
          event.id.hashCode + day,
          event.title,
          event.description ?? 'new task',
          _calculateNotificationTime(day, event.startTime),
          null,
        );

        if (event.endTime != null) {
          NotificationService().scheduleEndNotification(
            event.id.hashCode + day,
            event.title,
            event.description ?? 'new task',
            _calculateEndNotificationTime(day, event.endTime!),
            null,
          );
        }
      }
    } else {
      NotificationService().scheduleNotification(
        event.id.hashCode,
        event.title,
        event.description ?? 'new task',
        event.startTime,
        null,
      );

      if (event.endTime != null) {
        NotificationService().scheduleEndNotification(
          event.id.hashCode,
          event.title,
          event.description ?? 'new task',
          event.endTime!,
          null,
        );
      }
    }
  }

  void _cancelAllEventNotifications(Event event) {
    NotificationService().flutterLocalNotificationsPlugin.cancel(
      event.id.hashCode,
    );
    NotificationService().flutterLocalNotificationsPlugin.cancel(
      event.id.hashCode + 10000,
    );

    if (event.repeatDays.isNotEmpty) {
      for (int day in event.repeatDays) {
        NotificationService().flutterLocalNotificationsPlugin.cancel(
          event.id.hashCode + day,
        );
        NotificationService().flutterLocalNotificationsPlugin.cancel(
          event.id.hashCode + day + 10000,
        );
      }
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

  @override
  void dispose() {
    _eventsController.close();
    super.dispose();
  }
}