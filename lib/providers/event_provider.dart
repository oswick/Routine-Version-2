// lib/providers/event_provider.dart - VERSIÓN OPTIMIZADA
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

  // 🆕 NUEVO: Timer único para todas las actualizaciones
  Timer? _globalUpdateTimer;
  
  // 🆕 NUEVO: Cache de progreso por evento
  final Map<String, double> _progressCache = {};
  
  // 🆕 NUEVO: Cache de estado de completado por evento+día
  final Map<String, bool> _completionCache = {};

  final StreamController<List<Event>> _eventsController =
      StreamController<List<Event>>.broadcast();

  List<Event> get events => List.unmodifiable(_events);
  bool get isLoading => _isLoading;
  String? get error => _error;
  Stream<List<Event>> get eventsStream => _eventsController.stream;

  // 🆕 NUEVO: Obtener progreso cacheado
  double getEventProgress(String eventId) {
    return _progressCache[eventId] ?? 0.0;
  }

  // 🆕 NUEVO: Obtener estado de completado cacheado
  bool getEventCompletion(String eventId, DateTime date) {
    final key = _getCompletionCacheKey(eventId, date);
    return _completionCache[key] ?? false;
  }

  Future<void> init() async {
    await _syncService.init();
    await loadEvents();
    
    // 🆕 NUEVO: Iniciar timer único
    _startGlobalTimer();

    _authService.authStateChanges.listen((state) {
      if (state.event == AuthChangeEvent.signedIn) {
        loadEvents();
      } else if (state.event == AuthChangeEvent.signedOut) {
        _clearEvents();
      }
    });
  }

  // 🆕 NUEVO: Timer único que actualiza TODO
  void _startGlobalTimer() {
    _globalUpdateTimer?.cancel();
    
    // Timer que se ejecuta cada 5 segundos
    _globalUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      bool needsUpdate = false;
      final now = DateTime.now();
      
      // Actualizar progreso de eventos activos
      for (final event in _events) {
        if (event.endTime != null && !event.isCompleted && !event.isDeleted) {
          final newProgress = _calculateEventProgress(event, now);
          final currentProgress = _progressCache[event.id] ?? -1.0;
          
          // Solo actualizar si cambió significativamente (1% de diferencia)
          if ((newProgress - currentProgress).abs() > 0.01) {
            _progressCache[event.id] = newProgress;
            needsUpdate = true;
          }
        }
      }
      
      if (needsUpdate) {
        notifyListeners();
      }
    });
  }

  // 🆕 NUEVO: Calcular progreso sin crear timer
  double _calculateEventProgress(Event event, DateTime now) {
    if (event.endTime == null) return 0.0;

    if (event.repeatDays.isNotEmpty) {
      final today = now.weekday;
      if (!event.repeatDays.contains(today)) return 0.0;

      final todayStart = DateTime(
        now.year, now.month, now.day,
        event.startTime.hour, event.startTime.minute,
      );
      final todayEnd = DateTime(
        now.year, now.month, now.day,
        event.endTime!.hour, event.endTime!.minute,
      );

      if (now.isBefore(todayStart)) return 0.0;
      if (now.isAfter(todayEnd)) return 1.0;

      final total = todayEnd.difference(todayStart).inSeconds;
      final elapsed = now.difference(todayStart).inSeconds;
      return (elapsed / total).clamp(0.0, 1.0);
    } else {
      if (now.isBefore(event.startTime)) return 0.0;
      if (now.isAfter(event.endTime!)) return 1.0;

      final total = event.endTime!.difference(event.startTime).inSeconds;
      final elapsed = now.difference(event.startTime).inSeconds;
      return (elapsed / total).clamp(0.0, 1.0);
    }
  }

  String _getCompletionCacheKey(String eventId, DateTime date) {
    return '$eventId-${date.year}-${date.month}-${date.day}';
  }

  // 🆕 NUEVO: Actualizar estado de completado
  void updateEventCompletion(Event event, bool completed, DateTime date) {
    final key = _getCompletionCacheKey(event.id, date);
    _completionCache[key] = completed;
    
    // Si es evento único, actualizar el evento
    if (event.repeatDays.isEmpty) {
      final updatedEvent = event.copyWith(isCompleted: completed);
      updateEvent(updatedEvent);
    }
    
    notifyListeners();
  }

  Future<void> loadEvents() async {
    _setLoading(true);
    try {
      final loadedEvents = await _syncService.getEvents();
      _updateEvents(loadedEvents);
      
      // Actualizar cache de progreso inicial
      final now = DateTime.now();
      for (final event in loadedEvents) {
        if (event.endTime != null && !event.isCompleted) {
          _progressCache[event.id] = _calculateEventProgress(event, now);
        }
      }
      
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading events: $e');
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> addEvent(Event event) async {
    try {
      final userId = _authService.currentUserId ?? 'local_user';
      final newEvent = event.copyWith(
        id: _uuid.v4(),
        userId: userId,
        needsSync: _authService.isAuthenticated,
      );

      _events.add(newEvent);
      _notifyChanges();

      await _syncService.saveEvent(newEvent);

      if (!newEvent.isCompleted) {
        _scheduleEventNotifications(newEvent);
      }
    } catch (e) {
      await loadEvents();
      _error = e.toString();
      rethrow;
    }
  }

  // OPTIMIZADO: Sin recargar toda la lista
  Future<void> updateEvent(Event updatedEvent) async {
    try {
      final index = _events.indexWhere((e) => e.id == updatedEvent.id);
      if (index == -1) return;

      final oldEvent = _events[index];
      _events[index] = updatedEvent;
      
      // Actualizar cache de progreso
      if (updatedEvent.endTime != null) {
        _progressCache[updatedEvent.id] = _calculateEventProgress(
          updatedEvent, 
          DateTime.now()
        );
      }
      
      _notifyChanges();

      _syncService.saveEvent(updatedEvent).catchError((e) {
        debugPrint('Error saving event: $e');
        if (mounted && index < _events.length) {
          _events[index] = oldEvent;
          _notifyChanges();
        }
      });

      _cancelAllEventNotifications(oldEvent);
      if (!updatedEvent.isCompleted) {
        _scheduleEventNotifications(updatedEvent);
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error updating event: $e');
    }
  }

  Future<void> deleteEvent(String eventId, {bool deleteAll = false}) async {
    try {
      final eventIndex = _events.indexWhere((e) => e.id == eventId);
      if (eventIndex == -1) return;

      final event = _events[eventIndex];
      _events.removeAt(eventIndex);
      
      // Limpiar cache
      _progressCache.remove(eventId);
      _completionCache.removeWhere((key, _) => key.startsWith(eventId));
      
      _notifyChanges();

      _cancelAllEventNotifications(event);

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

  List<Event> getEventsForDay(DateTime day) {
    final Set<String> seenIds = {};
    return _events.where((event) {
      if (seenIds.contains(event.id)) return false;

      bool shouldInclude = false;

      if (event.repeatDays.isNotEmpty) {
        final eventCreationDate = DateTime(
          event.startTime.year,
          event.startTime.month,
          event.startTime.day,
        );
        final queryDate = DateTime(day.year, day.month, day.day);

        shouldInclude = event.repeatDays.contains(day.weekday) &&
            (queryDate.isAtSameMomentAs(eventCreationDate) ||
                queryDate.isAfter(eventCreationDate));
      } else {
        shouldInclude = _isSameDay(event.startTime, day);
      }

      if (shouldInclude) {
        seenIds.add(event.id);
        return true;
      }
      return false;
    }).toList();
  }

  void _updateEvents(List<Event> newEvents) {
    _events = newEvents;
    _notifyChanges();
  }

  void _clearEvents() {
    _events = [];
    _progressCache.clear();
    _completionCache.clear();
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

  bool get mounted => !_eventsController.isClosed;

  // Métodos de notificaciones (sin cambios)
  void _scheduleEventNotifications(Event event) async {
    _cancelAllEventNotifications(event);
    
    if (event.repeatDays.isNotEmpty) {
      for (int day in event.repeatDays) {
        await _scheduleNotificationForDay(event, day);
      }
    } else {
      await _scheduleSingleEventNotification(event);
    }
  }

  Future<void> _scheduleSingleEventNotification(Event event) async {
    final now = DateTime.now();
    
    if (event.startTime.isAfter(now)) {
      await NotificationService().scheduleNotification(
        event.id.hashCode,
        event.title,
        event.description ?? 'Recordatorio de evento',
        event.startTime,
        null,
      );

      if (event.endTime != null && event.endTime!.isAfter(now)) {
        await NotificationService().scheduleEndNotification(
          event.id.hashCode,
          event.title,
          event.description ?? 'Evento terminado',
          event.endTime!,
          null,
        );
      }
    }
  }

  Future<void> _scheduleNotificationForDay(Event event, int day) async {
    final now = DateTime.now();
    final nextNotificationTime = _calculateNotificationTime(day, event.startTime);
    
    if (nextNotificationTime.isAfter(now)) {
      final notificationId = event.id.hashCode + day;
      
      await NotificationService().scheduleNotification(
        notificationId,
        event.title,
        event.description ?? 'Recordatorio de evento',
        nextNotificationTime,
        null,
      );

      if (event.endTime != null) {
        final nextEndTime = _calculateEndNotificationTime(day, event.endTime!);
        if (nextEndTime.isAfter(now)) {
          await NotificationService().scheduleEndNotification(
            notificationId,
            event.title,
            event.description ?? 'Evento terminado',
            nextEndTime,
            null,
          );
        }
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
    
    if (daysUntilNext == 0) {
      final todayAtEventTime = DateTime(
        now.year, now.month, now.day,
        startTime.hour, startTime.minute,
      );
      
      if (todayAtEventTime.isAfter(now)) {
        return todayAtEventTime;
      } else {
        daysUntilNext = 7;
      }
    }
    
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
    
    if (daysUntilNext == 0) {
      final todayAtEventTime = DateTime(
        now.year, now.month, now.day,
        endTime.hour, endTime.minute,
      );
      
      if (todayAtEventTime.isAfter(now)) {
        return todayAtEventTime;
      } else {
        daysUntilNext = 7;
      }
    }
    
    DateTime nextNotificationDate = now.add(Duration(days: daysUntilNext));
    return DateTime(
      nextNotificationDate.year,
      nextNotificationDate.month,
      nextNotificationDate.day,
      endTime.hour,
      endTime.minute,
    );
  }

  Future<void> rescheduleAllNotifications() async {
    print('🔄 Reprogramando todas las notificaciones...');
    
    for (final event in _events) {
      if (!event.isCompleted && !event.isDeleted) {
        _scheduleEventNotifications(event);
      }
    }
    
    print('✅ Notificaciones reprogramadas');
  }
  
  @override
  void dispose() {
    _globalUpdateTimer?.cancel();
    _eventsController.close();
    _progressCache.clear();
    _completionCache.clear();
    super.dispose();
  }
}