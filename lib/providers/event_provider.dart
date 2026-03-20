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

  StreamSubscription<List<Event>>? _remoteChangesSub;

  List<Event> get events => List.unmodifiable(_events);
  bool get isLoading => _isLoading;
  String? get error => _error;
  Stream<List<Event>> get eventsStream => _eventsController.stream;

  double getEventProgress(String eventId) => _progressCache[eventId] ?? 0.0;

  bool getEventCompletion(String eventId, DateTime date) {
    final key = _getCompletionCacheKey(eventId, date);
    return _completionCache[key] ?? false;
  }

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    await _syncService.init();
    await _cleanOldCompletionStates();
    await loadEvents();
    await _loadTodayCompletionStates();

    _startGlobalTimer();
    _startDailyCleanupTimer();

    NotificationService().registerMarkDoneCallback((eventId) {
      markEventDoneFromNotification(eventId);
    });

    // Subscribe to REMOTE changes only.
    // SyncService emits on this stream only when another device changed data.
    // We merge those events surgically into _events without touching local writes.
    _remoteChangesSub =
        _syncService.remoteChangesStream.listen(_mergeRemoteChanges);

    _authService.authStateChanges.listen((state) {
      if (state.event == AuthChangeEvent.signedIn) {
        loadEvents();
      } else if (state.event == AuthChangeEvent.signedOut) {
        _clearEvents();
      }
    });

    await _processPendingBackgroundActions();
  }

  // ── Surgical merge of remote changes ─────────────────────────────────────
  // Called by SyncService when it downloads events from the server that were
  // changed by another device.  We update _events in-place so the UI sees the
  // change instantly without any full reload or blank flash.
  void _mergeRemoteChanges(List<Event> serverEvents) {
    if (serverEvents.isEmpty) return;
    debugPrint(
        '🔀 EventProvider: merging ${serverEvents.length} remote changes');

    bool changed = false;
    final now = DateTime.now();

    for (final serverEvent in serverEvents) {
      // Deletion flagged by SyncService.
      if (serverEvent.isDeleted) {
        final idx = _events.indexWhere((e) => e.id == serverEvent.id);
        if (idx != -1) {
          _events.removeAt(idx);
          _progressCache.remove(serverEvent.id);
          _completionCache
              .removeWhere((k, _) => k.startsWith(serverEvent.id));
          changed = true;
          debugPrint('🗑️ Merged deletion: ${serverEvent.id}');
        }
        continue;
      }

      final idx = _events.indexWhere((e) => e.id == serverEvent.id);
      if (idx == -1) {
        // New event from another device — add it.
        _events.add(serverEvent);
        if (serverEvent.endTime != null && !serverEvent.isCompleted) {
          _progressCache[serverEvent.id] =
              _calculateEventProgress(serverEvent, now);
        }
        changed = true;
        debugPrint('➕ Merged new event: ${serverEvent.title}');
      } else {
        // Existing event updated by another device.
        final local = _events[idx];
        // Don't overwrite if we have a pending local edit that is newer.
        if (local.needsSync &&
            local.lastModified.isAfter(serverEvent.lastModified)) {
          debugPrint(
              '⏭️ Skipping merge for ${serverEvent.id} (local edit is newer)');
          continue;
        }
        _events[idx] = serverEvent;
        if (serverEvent.endTime != null && !serverEvent.isCompleted) {
          _progressCache[serverEvent.id] =
              _calculateEventProgress(serverEvent, now);
        } else {
          _progressCache.remove(serverEvent.id);
        }
        changed = true;
        debugPrint('✏️ Merged update: ${serverEvent.title}');
      }
    }

    if (changed) {
      _dayCache.clear();
      _notifyChanges();
    }
  }

  // ── Notification helpers ──────────────────────────────────────────────────
  void markEventDoneFromNotification(String eventId) async {
    debugPrint('✔️ markEventDoneFromNotification: eventId=$eventId');
    final event = _events.cast<Event?>().firstWhere(
          (e) => e?.id == eventId,
          orElse: () => null,
        );
    if (event == null) {
      debugPrint('⚠️ markEventDoneFromNotification: $eventId not in memory');
      return;
    }
    await updateEventCompletion(event, true, DateTime.now());
  }

  Future<void> _processPendingBackgroundActions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList('pending_notif_actions') ?? [];
      if (pending.isEmpty) return;

      await prefs.remove('pending_notif_actions');
      debugPrint('📬 Processing ${pending.length} pending background actions');

      for (final entry in pending) {
        final parts = entry.split(':');
        if (parts.length != 2) continue;
        final actionId = parts[0];
        final firedId = int.tryParse(parts[1]);
        if (firedId == null) continue;

        if (actionId == 'mark_done') {
          final stored =
              await NotificationService().getNotificationDataById(firedId);
          final eventId = stored?.eventId;
          if (eventId != null) {
            final event = _events.cast<Event?>().firstWhere(
                  (e) => e?.id == eventId,
                  orElse: () => null,
                );
            if (event != null) {
              await updateEventCompletion(event, true, DateTime.now());
            }
          }
          await NotificationService().cancelSingleNotification(firedId);
        } else if (actionId == 'snooze') {
          await NotificationService().snoozeNotification(firedId);
        }
      }
    } catch (e) {
      debugPrint('Error processing pending background actions: $e');
    }
  }

  // ── Daily cleanup ─────────────────────────────────────────────────────────
  void _startDailyCleanupTimer() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    Timer(tomorrow.difference(now), () {
      _cleanOldCompletionStates();
      _startDailyCleanupTimer();
    });
  }

  Future<void> _cleanOldCompletionStates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final todayKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      int removed = 0;
      for (final key in prefs.getKeys()) {
        if (key.startsWith('event_') && key.contains('_completion_')) {
          final parts = key.split('_completion_');
          if (parts.length == 2 && parts[1] != todayKey) {
            await prefs.remove(key);
            removed++;
            final eventId = parts[0].replaceAll('event_', '');
            try {
              final dp = parts[1].split('-');
              if (dp.length == 3) {
                _completionCache.remove(_getCompletionCacheKey(
                    eventId,
                    DateTime(int.parse(dp[0]), int.parse(dp[1]),
                        int.parse(dp[2]))));
              }
            } catch (_) {}
          }
        }
      }
      if (removed > 0) debugPrint('🧹 Cleaned $removed old completion states');
    } catch (e) {
      debugPrint('Error cleaning completion states: $e');
    }
  }

  Future<void> _loadTodayCompletionStates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final todayKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      int loaded = 0;
      for (final key in prefs.getKeys()) {
        if (key.startsWith('event_') && key.contains('_completion_')) {
          final parts = key.split('_completion_');
          if (parts.length == 2 && parts[1] == todayKey) {
            final completed = prefs.getBool(key) ?? false;
            final eventId = parts[0].replaceAll('event_', '');
            _completionCache[_getCompletionCacheKey(eventId, today)] =
                completed;
            loaded++;
          }
        }
      }
      debugPrint('📥 Loaded $loaded completion states for today');
    } catch (e) {
      debugPrint('Error loading today completion states: $e');
    }
  }

  // ── Cache ─────────────────────────────────────────────────────────────────
  void _pruneCache() {
    if (_progressCache.length > _maxCacheSize) {
      for (final k in _progressCache.keys.take(100).toList()) {
        _progressCache.remove(k);
      }
    }
    if (_completionCache.length > _maxCacheSize) {
      for (final k in _completionCache.keys.take(100).toList()) {
        _completionCache.remove(k);
      }
    }
    if (_dayCache.length > _maxDayCacheSize) {
      for (final k in _dayCache.keys.take(10).toList()) {
        _dayCache.remove(k);
      }
    }
  }

  // ── Progress timer ────────────────────────────────────────────────────────
  void _startGlobalTimer() {
    _globalUpdateTimer?.cancel();
    _scheduleNextUpdate();
  }

  void _scheduleNextUpdate() {
    final next = _calculateNextUpdateTime();
    if (next == null) {
      _globalUpdateTimer =
          Timer(const Duration(minutes: 1), () {
        if (mounted) _scheduleNextUpdate();
      });
      return;
    }
    final duration = next.difference(DateTime.now());
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
      if (event.endTime == null || event.isCompleted || event.isDeleted) {
        continue;
      }
      DateTime? t;
      if (event.repeatDays.isNotEmpty) {
        if (event.repeatDays.contains(now.weekday)) {
          final todayEnd = DateTime(now.year, now.month, now.day,
              event.endTime!.hour, event.endTime!.minute);
          if (todayEnd.isAfter(now)) t = todayEnd;
        }
      } else {
        if (event.endTime!.isAfter(now)) t = event.endTime;
      }
      if (t != null && (nearest == null || t.isBefore(nearest))) nearest = t;
    }
    return nearest;
  }

  void _updateActiveEvents() {
    bool needsUpdate = false;
    final now = DateTime.now();
    for (final event in _events) {
      if (event.endTime != null && !event.isCompleted && !event.isDeleted) {
        final p = _calculateEventProgress(event, now);
        final cur = _progressCache[event.id] ?? -1.0;
        if ((p - cur).abs() > 0.001) {
          _progressCache[event.id] = p;
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
      final s = DateTime(now.year, now.month, now.day,
          event.startTime.hour, event.startTime.minute);
      final e = DateTime(now.year, now.month, now.day,
          event.endTime!.hour, event.endTime!.minute);
      if (now.isBefore(s)) return 0.0;
      if (now.isAfter(e)) return 1.0;
      return (now.difference(s).inMilliseconds /
              e.difference(s).inMilliseconds)
          .clamp(0.0, 1.0);
    } else {
      if (now.isBefore(event.startTime)) return 0.0;
      if (now.isAfter(event.endTime!)) return 1.0;
      return (now.difference(event.startTime).inMilliseconds /
              event.endTime!.difference(event.startTime).inMilliseconds)
          .clamp(0.0, 1.0);
    }
  }

  String _getCompletionCacheKey(String eventId, DateTime date) =>
      '$eventId-${date.year}-${date.month}-${date.day}';

  // ── CRUD ──────────────────────────────────────────────────────────────────
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
      } catch (e) {
        debugPrint('Error saving completion state: $e');
      }
    } else {
      await updateEvent(event.copyWith(isCompleted: completed));
    }
    notifyListeners();
  }

  Future<void> loadEvents() async {
    _setLoading(true);
    try {
      final loaded = await _syncService.getEvents();
      _updateEvents(loaded);
      final now = DateTime.now();
      for (final e in loaded) {
        if (e.endTime != null && !e.isCompleted) {
          _progressCache[e.id] = _calculateEventProgress(e, now);
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

      // Optimistic update — add to memory immediately so UI responds instantly.
      _events.add(newEvent);
      _dayCache.clear();
      _notifyChanges();

      // Persist locally and schedule upload (non-blocking).
      await _syncService.saveEvent(newEvent);

      if (!newEvent.isCompleted) {
        await _scheduleEventNotifications(newEvent);
      }
      _pruneCache();
    } catch (e) {
      // Rollback on failure.
      _events.removeWhere((ev) => ev.title == event.title);
      _dayCache.clear();
      _notifyChanges();
      _error = e.toString();
      rethrow;
    }
  }

  Future<void> updateEvent(Event updatedEvent) async {
    final index = _events.indexWhere((e) => e.id == updatedEvent.id);
    if (index == -1) return;

    final oldEvent = _events[index];

    // Optimistic update.
    _events[index] = updatedEvent;
    if (updatedEvent.endTime != null) {
      _progressCache[updatedEvent.id] =
          _calculateEventProgress(updatedEvent, DateTime.now());
    }
    _dayCache.clear();
    _notifyChanges();

    try {
      await _syncService.saveEvent(updatedEvent);
      await _cancelAllEventNotifications(oldEvent);
      if (!updatedEvent.isCompleted) {
        await _scheduleEventNotifications(updatedEvent);
      }
    } catch (e) {
      // Rollback on failure.
      if (mounted && index < _events.length) {
        _events[index] = oldEvent;
        _dayCache.clear();
        _notifyChanges();
      }
      _error = e.toString();
      debugPrint('Error updating event: $e');
    }
  }

  Future<void> deleteEvent(String eventId,
      {bool deleteAll = false}) async {
    final idx = _events.indexWhere((e) => e.id == eventId);
    if (idx == -1) return;

    final event = _events[idx];

    // Optimistic removal — disappears from UI immediately.
    await _cancelAllEventNotifications(event);
    _events.removeAt(idx);
    _progressCache.remove(eventId);
    _completionCache.removeWhere((k, _) => k.startsWith(eventId));
    _dayCache.clear();

    try {
      final prefs = await SharedPreferences.getInstance();
      for (final k in prefs
          .getKeys()
          .where((k) => k.startsWith('event_$eventId'))
          .toList()) {
        await prefs.remove(k);
      }
    } catch (_) {}

    _notifyChanges();

    try {
      if (deleteAll) {
        await _syncService.deleteAllEventInstances(eventId);
      } else {
        await _syncService.deleteEvent(eventId);
      }
    } catch (e) {
      // Rollback on failure.
      _events.insert(idx, event);
      _dayCache.clear();
      _notifyChanges();
      _error = e.toString();
      rethrow;
    }
  }

  // ── Query ─────────────────────────────────────────────────────────────────
  List<Event> getEventsForDay(DateTime day) {
    final cacheKey = '${day.year}-${day.month}-${day.day}';
    if (_dayCache.containsKey(cacheKey)) return _dayCache[cacheKey]!;

    final seen = <String>{};
    final result = _events.where((event) {
      if (seen.contains(event.id)) return false;
      bool include;
      if (event.repeatDays.isNotEmpty) {
        final created = DateTime(event.startTime.year,
            event.startTime.month, event.startTime.day);
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

  // ── Internal ──────────────────────────────────────────────────────────────
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
    if (!_eventsController.isClosed) _eventsController.add(_events);
    notifyListeners();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get mounted => !_eventsController.isClosed;

  // ── Notification helpers ──────────────────────────────────────────────────
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
          baseId, event.title, event.description ?? '', event.startTime, null,
          eventId: event.id);
    }
    if (event.endTime != null && event.endTime!.isAfter(now)) {
      await NotificationService().scheduleEndNotification(
          baseId, event.title, event.description ?? '', event.endTime!, null,
          eventId: event.id);
    }
  }

  Future<void> _scheduleNotificationForDay(Event event, int day) async {
    final now = DateTime.now();
    final baseId = event.id.hashCode + day;
    final nextStart = _calcNotifTime(day, event.startTime);
    if (nextStart.isAfter(now)) {
      await NotificationService().scheduleNotification(
          baseId, event.title, event.description ?? '', nextStart, null,
          eventId: event.id);
    }
    if (event.endTime != null) {
      final nextEnd = _calcNotifTime(day, event.endTime!);
      if (nextEnd.isAfter(now)) {
        await NotificationService().scheduleEndNotification(
            baseId, event.title, event.description ?? '', nextEnd, null,
            eventId: event.id);
      }
    }
  }

  Future<void> _cancelAllEventNotifications(Event event) async {
    await NotificationService().cancelEventNotifications(
      event.id,
      repeatDays: event.repeatDays.isNotEmpty ? event.repeatDays : null,
    );
  }

  DateTime _calcNotifTime(int day, DateTime t) {
    final now = DateTime.now();
    int ahead = (day - now.weekday + 7) % 7;
    if (ahead == 0) {
      final today = DateTime(now.year, now.month, now.day, t.hour, t.minute);
      if (today.isAfter(now)) return today;
      ahead = 7;
    }
    final d = now.add(Duration(days: ahead));
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> rescheduleAllNotifications() async {
    for (final event in _events) {
      if (!event.isCompleted && !event.isDeleted) {
        await _scheduleEventNotifications(event);
      }
    }
  }

  @override
  void dispose() {
    _globalUpdateTimer?.cancel();
    _remoteChangesSub?.cancel();
    _eventsController.close();
    _progressCache.clear();
    _completionCache.clear();
    _dayCache.clear();
    super.dispose();
  }
}