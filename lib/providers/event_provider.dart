// lib/providers/event_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event.dart';
import '../services/sync_service.dart';
import '../services/auth_service.dart';
import '../utils/notification_service.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Timer? _globalUpdateTimer;
  final Map<String, double> _progressCache = {};
  final Map<String, bool> _completionCache = {};
  final Map<String, List<Event>> _dayCache = {};
  static const int _maxDayCacheSize = 30;
  static const int _maxCacheSize = 1000;

  final StreamController<List<Event>> _eventsController =
      StreamController<List<Event>>.broadcast();

  List<Event> get events => List.unmodifiable(_events);
  bool get isLoading => _isLoading;
  String? get error => _error;
  Stream<List<Event>> get eventsStream => _eventsController.stream;

  double getEventProgress(String eventId) {
    return _progressCache[eventId] ?? 0.0;
  }

  bool getEventCompletion(String eventId, DateTime date) {
    final key = _getCompletionCacheKey(eventId, date);
    return _completionCache[key] ?? false;
  }

  Future<void> init() async {
    await _syncService.init();
    await _cleanOldCompletionStates();
    await loadEvents();
    await _loadTodayCompletionStates();

    _startGlobalTimer();
    _startDailyCleanupTimer();

    // Registrar callback para que NotificationService pueda marcar
    // eventos como completados cuando el usuario pulsa "Completado"
    // en la notificación, sin necesidad de un BuildContext.
    NotificationService().registerMarkDoneCallback((eventId) {
      markEventDoneFromNotification(eventId);
    });

    _authService.authStateChanges.listen((state) {
      if (state.event == AuthChangeEvent.signedIn) {
        loadEvents();
      } else if (state.event == AuthChangeEvent.signedOut) {
        _clearEvents();
      }
    });

    // Procesar acciones que se encolaron mientras la app estaba cerrada
    // (pulsaciones de botón en notificaciones con la app en background/killed).
    await _processPendingBackgroundActions();
  }

  // ── Acción desde notificación ─────────────────────────────────────────────
  //
  // Llamado por NotificationService cuando el usuario pulsa "Completado"
  // en una notificación. [eventId] es el ID del evento (String UUID).
  //
  // Para eventos repetitivos: marca el completado de HOY en SharedPreferences
  // y en el cache de memoria, y notifica a la UI.
  // Para eventos únicos: actualiza isCompleted = true y sincroniza.
// Replace markEventDoneFromNotification in event_provider.dart
void markEventDoneFromNotification(String eventId) async {
  debugPrint('✔️ markEventDoneFromNotification: eventId=$eventId');

  // FIX: safe lookup — don't throw if event not in memory yet
  final event = _events.cast<Event?>().firstWhere(
    (e) => e?.id == eventId,
    orElse: () => null,
  );

  if (event == null) {
    debugPrint('⚠️ markEventDoneFromNotification: event $eventId not found in memory');
    return;
  }

  final today = DateTime.now();
  await updateEventCompletion(event, true, today);
  debugPrint('✅ Event "$eventId" marked done from notification');
}


  // ── Procesar acciones encoladas desde background ─────────────────────────
  //
  // Cuando la app estaba killed y el usuario pulsó "Completado" o "Posponer",
  // notificationBackgroundHandler() guardó la acción en SharedPreferences.
  // Este método las lee y las ejecuta ahora que la app está activa.
Future<void> _processPendingBackgroundActions() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList('pending_notif_actions') ?? [];
    if (pending.isEmpty) return;

    // Clear immediately to avoid double-processing
    await prefs.remove('pending_notif_actions');
    debugPrint('📬 Processing ${pending.length} pending background actions');

    for (final entry in pending) {
      final parts = entry.split(':');
      if (parts.length != 2) continue;
      final actionId = parts[0];
      final firedId = int.tryParse(parts[1]);
      if (firedId == null) continue;

      if (actionId == 'mark_done') {
        // FIX: look up the stored notification data to get the eventId string
        final stored = await NotificationService().getNotificationDataById(firedId);
        final eventId = stored?.eventId;

        if (eventId != null) {
          // FIX: call the logic directly — don't rely on callback being registered
          final event = _events.cast<Event?>().firstWhere(
            (e) => e?.id == eventId,
            orElse: () => null,
          );
          if (event != null) {
            await updateEventCompletion(event, true, DateTime.now());
            debugPrint('✅ Background mark_done processed for event $eventId');
          } else {
            debugPrint('⚠️ Background mark_done: event $eventId not in memory');
          }
        } else {
          debugPrint('⚠️ Background mark_done: no eventId for notif $firedId');
        }
        await NotificationService().cancelSingleNotification(firedId);

      } else if (actionId == 'snooze') {
        await NotificationService().snoozeNotification(firedId);
        debugPrint('⏸️ Background snooze processed for notif $firedId');
      }
    }
  } catch (e) {
    debugPrint('Error processing pending background actions: $e');
  }
}
  void _startDailyCleanupTimer() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final durationUntilMidnight = tomorrow.difference(now);

    Timer(durationUntilMidnight, () {
      _cleanOldCompletionStates();
      _startDailyCleanupTimer();
    });
  }

  Future<void> _cleanOldCompletionStates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final today = DateTime.now();
      final todayKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      int removedCount = 0;

      for (final key in keys) {
        if (key.startsWith('event_') && key.contains('_completion_')) {
          final parts = key.split('_completion_');
          if (parts.length == 2 && parts[1] != todayKey) {
            await prefs.remove(key);
            removedCount++;

            final eventId = parts[0].replaceAll('event_', '');
            try {
              final dateParts = parts[1].split('-');
              if (dateParts.length == 3) {
                final date = DateTime(
                  int.parse(dateParts[0]),
                  int.parse(dateParts[1]),
                  int.parse(dateParts[2]),
                );
                _completionCache.remove(_getCompletionCacheKey(eventId, date));
              }
            } catch (e) {
              debugPrint('Error parsing date during cleanup: $e');
            }
          }
        }
      }

      if (removedCount > 0) {
        debugPrint('🧹 Cleaned $removedCount old completion states');
      }
    } catch (e) {
      debugPrint('Error cleaning old completion states: $e');
    }
  }

  Future<void> _loadTodayCompletionStates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final todayKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      int loadedCount = 0;

      for (final key in prefs.getKeys()) {
        if (key.startsWith('event_') && key.contains('_completion_')) {
          final parts = key.split('_completion_');
          if (parts.length == 2 && parts[1] == todayKey) {
            final completed = prefs.getBool(key) ?? false;
            final eventId = parts[0].replaceAll('event_', '');
            _completionCache[_getCompletionCacheKey(eventId, today)] = completed;
            loadedCount++;
          }
        }
      }

      debugPrint('📥 Loaded $loadedCount completion states for today');
    } catch (e) {
      debugPrint('Error loading today completion states: $e');
    }
  }

  void _pruneCache() {
    if (_progressCache.length > _maxCacheSize) {
      final keysToRemove = _progressCache.keys.take(100).toList();
      for (final key in keysToRemove) {
        _progressCache.remove(key);
      }
    }
    if (_completionCache.length > _maxCacheSize) {
      final keysToRemove = _completionCache.keys.take(100).toList();
      for (final key in keysToRemove) {
        _completionCache.remove(key);
      }
    }
    if (_dayCache.length > _maxDayCacheSize) {
      final keysToRemove = _dayCache.keys.take(10).toList();
      for (final key in keysToRemove) {
        _dayCache.remove(key);
      }
    }
  }

  void _startGlobalTimer() {
    _globalUpdateTimer?.cancel();
    _scheduleNextUpdate();
  }

  void _scheduleNextUpdate() {
    final nextUpdateTime = _calculateNextUpdateTime();

    if (nextUpdateTime == null) {
      _globalUpdateTimer = Timer(const Duration(minutes: 1), () {
        if (mounted) _scheduleNextUpdate();
      });
      return;
    }

    final now = DateTime.now();
    final duration = nextUpdateTime.difference(now);

    if (duration.isNegative) {
      _scheduleNextUpdate();
      return;
    }

    _globalUpdateTimer = Timer(duration, () {
      if (!mounted) return;
      _updateActiveEvents();
      _scheduleNextUpdate();
    });
  }

  DateTime? _calculateNextUpdateTime() {
    DateTime? nearest;
    final now = DateTime.now();

    for (final event in _events) {
      if (event.endTime == null || event.isCompleted || event.isDeleted) continue;

      DateTime? eventTime;

      if (event.repeatDays.isNotEmpty) {
        if (event.repeatDays.contains(now.weekday)) {
          final todayEnd = DateTime(
            now.year, now.month, now.day,
            event.endTime!.hour, event.endTime!.minute,
          );
          if (todayEnd.isAfter(now)) eventTime = todayEnd;
        }
      } else {
        if (event.endTime!.isAfter(now)) eventTime = event.endTime;
      }

      if (eventTime != null && (nearest == null || eventTime.isBefore(nearest))) {
        nearest = eventTime;
      }
    }

    return nearest;
  }

  void _updateActiveEvents() {
    bool needsUpdate = false;
    final now = DateTime.now();

    for (final event in _events) {
      if (event.endTime != null && !event.isCompleted && !event.isDeleted) {
        final newProgress = _calculateEventProgress(event, now);
        final currentProgress = _progressCache[event.id] ?? -1.0;

        if ((newProgress - currentProgress).abs() > 0.001) {
          _progressCache[event.id] = newProgress;
          needsUpdate = true;
        }
      }
    }

    if (needsUpdate) notifyListeners();
  }

  double _calculateEventProgress(Event event, DateTime now) {
    if (event.endTime == null) return 0.0;

    if (event.repeatDays.isNotEmpty) {
      if (!event.repeatDays.contains(now.weekday)) return 0.0;

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

      final total = todayEnd.difference(todayStart).inMilliseconds;
      final elapsed = now.difference(todayStart).inMilliseconds;
      return (elapsed / total).clamp(0.0, 1.0);
    } else {
      if (now.isBefore(event.startTime)) return 0.0;
      if (now.isAfter(event.endTime!)) return 1.0;

      final total = event.endTime!.difference(event.startTime).inMilliseconds;
      final elapsed = now.difference(event.startTime).inMilliseconds;
      return (elapsed / total).clamp(0.0, 1.0);
    }
  }

  String _getCompletionCacheKey(String eventId, DateTime date) {
    return '$eventId-${date.year}-${date.month}-${date.day}';
  }

  Future<void> updateEventCompletion(
      Event event, bool completed, DateTime date) async {
    final key = _getCompletionCacheKey(event.id, date);
    _completionCache[key] = completed;

    if (event.repeatDays.isNotEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final prefKey =
            'event_${event.id}_completion_${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        await prefs.setBool(prefKey, completed);
        debugPrint('💾 Saved completion state: $prefKey = $completed');
      } catch (e) {
        debugPrint('Error saving completion state: $e');
      }
    } else {
      final updatedEvent = event.copyWith(isCompleted: completed);
      await updateEvent(updatedEvent);
    }

    notifyListeners();
  }

  Future<void> loadEvents() async {
    _setLoading(true);
    try {
      final loadedEvents = await _syncService.getEvents();
      _updateEvents(loadedEvents);

      final now = DateTime.now();
      for (final event in loadedEvents) {
        if (event.endTime != null && !event.isCompleted) {
          _progressCache[event.id] = _calculateEventProgress(event, now);
        }
      }

      await _loadTodayCompletionStates();
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
      _dayCache.clear();
      _notifyChanges();

      await _syncService.saveEvent(newEvent);

      if (!newEvent.isCompleted) {
        await _scheduleEventNotifications(newEvent);
      }

      _pruneCache();
    } catch (e) {
      await loadEvents();
      _error = e.toString();
      rethrow;
    }
  }

  Future<void> updateEvent(Event updatedEvent) async {
    try {
      final index = _events.indexWhere((e) => e.id == updatedEvent.id);
      if (index == -1) return;

      final oldEvent = _events[index];
      _events[index] = updatedEvent;

      if (updatedEvent.endTime != null) {
        _progressCache[updatedEvent.id] =
            _calculateEventProgress(updatedEvent, DateTime.now());
      }

      _dayCache.clear();
      _notifyChanges();

      _syncService.saveEvent(updatedEvent).catchError((e) {
        debugPrint('Error saving event: $e');
        if (mounted && index < _events.length) {
          _events[index] = oldEvent;
          _dayCache.clear();
          _notifyChanges();
        }
      });

      await _cancelAllEventNotifications(oldEvent);
      if (!updatedEvent.isCompleted) {
        await _scheduleEventNotifications(updatedEvent);
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
      await _cancelAllEventNotifications(event);

      _events.removeAt(eventIndex);
      _progressCache.remove(eventId);
      _completionCache.removeWhere((key, _) => key.startsWith(eventId));
      _dayCache.clear();

      try {
        final prefs = await SharedPreferences.getInstance();
        final keysToRemove = prefs
            .getKeys()
            .where((key) => key.startsWith('event_$eventId'))
            .toList();
        for (final key in keysToRemove) {
          await prefs.remove(key);
        }
      } catch (e) {
        debugPrint('Error cleaning SharedPreferences: $e');
      }

      _notifyChanges();

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
    final cacheKey = '${day.year}-${day.month}-${day.day}';

    if (_dayCache.containsKey(cacheKey)) return _dayCache[cacheKey]!;

    final seen = <String>{};
    final result = _events.where((event) {
      if (seen.contains(event.id)) return false;

      bool include;
      if (event.repeatDays.isNotEmpty) {
        final created = DateTime(
          event.startTime.year, event.startTime.month, event.startTime.day);
        final query = DateTime(day.year, day.month, day.day);
        include = event.repeatDays.contains(day.weekday) &&
            (query.isAtSameMomentAs(created) || query.isAfter(created));
      } else {
        include = _isSameDay(event.startTime, day);
      }

      if (include) seen.add(event.id);
      return include;
    }).toList();

    _dayCache[cacheKey] = result;
    if (_dayCache.length > _maxDayCacheSize) {
      _dayCache.remove(_dayCache.keys.first);
    }

    return result;
  }

  void _updateEvents(List<Event> newEvents) {
    _events = newEvents;
    _dayCache.clear();
    _notifyChanges();
  }

  void _clearEvents() {
    _events = [];
    _progressCache.clear();
    _completionCache.clear();
    _dayCache.clear();
    _notifyChanges();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _notifyChanges() {
    if (!_eventsController.isClosed) {
      _eventsController.add(_events);
    }
    notifyListeners();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get mounted => !_eventsController.isClosed;

  // ── Notification helpers ──────────────────────────────────────────────────
  //
  // ID scheme:
  //   Evento único      : eventId.hashCode
  //   Repetitivo día N  : eventId.hashCode + N   (N = 1..7)
  //
  // NotificationService añade +10_000 internamente para las notificaciones
  // de fin. Siempre pasamos el ID base aquí.

  Future<void> _scheduleEventNotifications(Event event) async {
    await _cancelAllEventNotifications(event);

    if (event.repeatDays.isNotEmpty) {
      for (final day in event.repeatDays) {
        await _scheduleNotificationForDay(event, day);
      }
    } else {
      await _scheduleSingleEventNotification(event);
    }
  }

  Future<void> _scheduleSingleEventNotification(Event event) async {
    final now = DateTime.now();
    final baseId = event.id.hashCode;

    if (event.startTime.isAfter(now)) {
      await NotificationService().scheduleNotification(
        baseId,
        event.title,
        event.description ?? 'Recordatorio de evento',
        event.startTime,
        null,
        eventId: event.id,   // ← para que mark_done sepa qué evento marcar
      );
    }

    if (event.endTime != null && event.endTime!.isAfter(now)) {
      await NotificationService().scheduleEndNotification(
        baseId,             // ← base id; el servicio añade +10_000
        event.title,
        event.description ?? 'Evento terminado',
        event.endTime!,
        null,
        eventId: event.id,
      );
    }
  }

  Future<void> _scheduleNotificationForDay(Event event, int day) async {
    final now = DateTime.now();
    final baseId = event.id.hashCode + day;
    final nextStart = _calculateNotificationTime(day, event.startTime);

    if (nextStart.isAfter(now)) {
      await NotificationService().scheduleNotification(
        baseId,
        event.title,
        event.description ?? 'Recordatorio de evento',
        nextStart,
        null,
        eventId: event.id,
      );
    }

    if (event.endTime != null) {
      final nextEnd = _calculateEndNotificationTime(day, event.endTime!);
      if (nextEnd.isAfter(now)) {
        await NotificationService().scheduleEndNotification(
          baseId,           // ← base id; el servicio añade +10_000
          event.title,
          event.description ?? 'Evento terminado',
          nextEnd,
          null,
          eventId: event.id,
        );
      }
    }
  }

  Future<void> _cancelAllEventNotifications(Event event) async {
    await NotificationService().cancelEventNotifications(
      event.id,
      repeatDays: event.repeatDays.isNotEmpty ? event.repeatDays : null,
    );
  }

  DateTime _calculateNotificationTime(int day, DateTime startTime) {
    final now = DateTime.now();
    int daysUntilNext = (day - now.weekday + 7) % 7;

    if (daysUntilNext == 0) {
      final todayAtEventTime = DateTime(
        now.year, now.month, now.day,
        startTime.hour, startTime.minute,
      );
      if (todayAtEventTime.isAfter(now)) return todayAtEventTime;
      daysUntilNext = 7;
    }

    final nextDate = now.add(Duration(days: daysUntilNext));
    return DateTime(
      nextDate.year, nextDate.month, nextDate.day,
      startTime.hour, startTime.minute,
    );
  }

  DateTime _calculateEndNotificationTime(int day, DateTime endTime) {
    final now = DateTime.now();
    int daysUntilNext = (day - now.weekday + 7) % 7;

    if (daysUntilNext == 0) {
      final todayAtEventTime = DateTime(
        now.year, now.month, now.day,
        endTime.hour, endTime.minute,
      );
      if (todayAtEventTime.isAfter(now)) return todayAtEventTime;
      daysUntilNext = 7;
    }

    final nextDate = now.add(Duration(days: daysUntilNext));
    return DateTime(
      nextDate.year, nextDate.month, nextDate.day,
      endTime.hour, endTime.minute,
    );
  }

  Future<void> rescheduleAllNotifications() async {
    debugPrint('🔄 Reprogramando todas las notificaciones...');
    for (final event in _events) {
      if (!event.isCompleted && !event.isDeleted) {
        await _scheduleEventNotifications(event);
      }
    }
    debugPrint('✅ Notificaciones reprogramadas');
  }

  @override
  void dispose() {
    _globalUpdateTimer?.cancel();
    _eventsController.close();
    _progressCache.clear();
    _completionCache.clear();
    _dayCache.clear();
    super.dispose();
  }
}