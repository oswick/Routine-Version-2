import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../models/event.dart';
import '../../../utils/notification_service.dart';
import '../models/focus_config.dart';
import '../models/focus_phase.dart';
import '../models/focus_session.dart';
import '../services/focus_storage_service.dart';
import '../services/focus_timer_engine.dart';

sealed class FocusState { const FocusState(); }
final class FocusReady extends FocusState { const FocusReady({this.eventId}); final String? eventId; }
final class FocusActive extends FocusState { const FocusActive({required this.eventId, required this.phase}); final String? eventId; final FocusPhase phase; }
final class FocusBreak extends FocusState { const FocusBreak({required this.phase}); final FocusPhase phase; }
final class FocusCompleted extends FocusState { const FocusCompleted({required this.phase, required this.session}); final FocusPhase phase; final FocusSession session; }

class FocusProvider extends ChangeNotifier {
  FocusProvider({FocusStorageService? storage}) : _storage = storage ?? FocusStorageService();
  final FocusStorageService _storage;
  final Uuid _uuid = const Uuid();
  final NotificationService _notifications = NotificationService();
  FocusState _state = const FocusReady();
  FocusTimerEngine? _engine;
  String? _eventId;
  Event? _activeEvent;
  FocusPhase _phase = FocusPhase.focus;
  int _completedFocusSessions = 0;
  FocusSession? _currentSession;
  Timer? _completionGuard;

  FocusState get state => _state;
  FocusTimerEngine? get timer => _engine;
  String? get eventId => _eventId;
  Event? get activeEvent => _activeEvent;
  FocusPhase get phase => _phase;
  int get completedFocusSessions => _completedFocusSessions;
  FocusSession? get currentSession => _currentSession;
  Duration get remaining => _engine?.remaining ?? _durationFor(_phase);
  Duration get elapsed => _engine?.elapsed ?? Duration.zero;
  double get progress => _engine?.progress ?? 0;
  bool get isRunning => _engine?.isRunning ?? false;

  /// Keeps Focus synchronized with the same events shown by Home/Calendar.
  /// If an event has both start/end times and is currently happening, Focus
  /// immediately adopts it and starts from the event's real start timestamp.
  void syncWithEvents(List<Event> events, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final event = _findCurrentTimedEvent(events, current);
    if (event == null) return;
    if (_eventId == event.id && _engine?.isRunning == true) return;
    if (_state is FocusBreak || _state is FocusCompleted) return;
    _eventId = event.id;
    _activeEvent = event;
    _startScheduledEvent(event, current);
  }

  Event? _findCurrentTimedEvent(List<Event> events, DateTime now) {
    Event? result;
    for (final event in events) {
      if (event.isCompleted || event.isDeleted || event.endTime == null) continue;
      final start = _occurrenceStart(event, now);
      final end = _occurrenceEnd(event, now);
      final scheduledToday = event.repeatDays.isNotEmpty
          ? event.repeatDays.contains(now.weekday)
          : start.year == now.year && start.month == now.month && start.day == now.day;
      if (!scheduledToday || now.isBefore(start) || !now.isBefore(end) || end.difference(start) <= Duration.zero) continue;
      if (result == null || start.isAfter(_occurrenceStart(result, now))) result = event;
    }
    return result;
  }

  DateTime _occurrenceStart(Event event, DateTime now) => event.repeatDays.isEmpty
      ? event.startTime
      : DateTime(now.year, now.month, now.day, event.startTime.hour, event.startTime.minute);
  DateTime _occurrenceEnd(Event event, DateTime now) => event.repeatDays.isEmpty
      ? event.endTime!
      : DateTime(now.year, now.month, now.day, event.endTime!.hour, event.endTime!.minute);

  void _startScheduledEvent(Event event, DateTime now) {
    final start = _occurrenceStart(event, now);
    final end = _occurrenceEnd(event, now);
    final duration = end.difference(start);
    if (duration <= Duration.zero) return;
    _cancelNotification();
    _engine?.dispose();
    _phase = FocusPhase.focus;
    _engine = FocusTimerEngine(plannedDuration: duration, onTick: notifyListeners, onCompleted: _handleTimerCompleted);
    _currentSession = FocusSession(id: _uuid.v4(), eventId: event.id, startedAt: start, duration: duration, type: FocusPhase.focus);
    _state = FocusActive(eventId: event.id, phase: FocusPhase.focus);
    _engine!.startAt(start);
    _scheduleNotification();
    notifyListeners();
  }

  void selectEvent(String? id, {Event? event}) {
    if (_engine?.isRunning == true) return;
    _eventId = id;
    _activeEvent = event;
    _state = FocusReady(eventId: id);
    notifyListeners();
  }
  void startFocus() => _startPhase(FocusPhase.focus);
  void startBreak() { if (_phase != FocusPhase.focus) _startPhase(_phase); }
  void startNextPhase() => _startPhase(_phase == FocusPhase.focus ? (_completedFocusSessions % FocusConfig.sessionsBeforeLongBreak == 0 ? FocusPhase.longBreak : FocusPhase.shortBreak) : FocusPhase.focus);
  void pause() { _engine?.pause(); _rescheduleNotification(); notifyListeners(); }
  void resume() { _engine?.resume(); _scheduleNotification(); notifyListeners(); }
  void reset() { _cancelNotification(); _engine?.dispose(); _engine = null; _completionGuard?.cancel(); _completionGuard = null; _currentSession = null; _phase = FocusPhase.focus; _state = FocusReady(eventId: _eventId); notifyListeners(); }
  void addFiveMinutes() { _engine?.addTime(const Duration(minutes: 5)); _rescheduleNotification(); notifyListeners(); }
  void finishEarly() {
    final engine = _engine;
    if (engine == null || engine.elapsed == Duration.zero) return;
    engine.pause(); _cancelNotification();
    final session = _buildSession(completed: false, interrupted: true);
    _currentSession = session; unawaited(_persistSession(session));
    _state = FocusCompleted(phase: _phase, session: session); notifyListeners();
  }
  void skipBreak() { if (_phase == FocusPhase.focus) return; _cancelNotification(); _engine?.dispose(); _engine = null; _phase = FocusPhase.focus; _state = FocusReady(eventId: _eventId); notifyListeners(); }

  void _startPhase(FocusPhase phase) {
    _cancelNotification(); _engine?.dispose(); _completionGuard?.cancel(); _phase = phase;
    _engine = FocusTimerEngine(plannedDuration: _durationFor(phase), onTick: notifyListeners, onCompleted: _handleTimerCompleted);
    if (phase == FocusPhase.focus) {
      _currentSession = FocusSession(id: _uuid.v4(), eventId: _eventId, startedAt: DateTime.now(), duration: _durationFor(phase), type: phase);
      _state = FocusActive(eventId: _eventId, phase: phase);
    } else { _state = FocusBreak(phase: phase); }
    _engine!.start(); _scheduleNotification(); notifyListeners();
  }

  void _handleTimerCompleted() {
    if (_engine == null || _completionGuard != null) return;
    _cancelNotification();
    _completionGuard = Timer(const Duration(milliseconds: 50), () {
      _completionGuard = null;
      final session = _phase == FocusPhase.focus ? _buildSession(completed: true, interrupted: false) : FocusSession(id: _uuid.v4(), eventId: _eventId, startedAt: DateTime.now().subtract(_durationFor(_phase)), endedAt: DateTime.now(), duration: _durationFor(_phase), type: _phase, completed: true);
      if (_phase == FocusPhase.focus) { _completedFocusSessions++; _currentSession = session; }
      unawaited(_persistSession(session));
      _state = FocusCompleted(phase: _phase, session: session); notifyListeners();
    });
  }

  FocusSession _buildSession({required bool completed, required bool interrupted}) => FocusSession(id: _currentSession?.id ?? _uuid.v4(), eventId: _eventId, startedAt: _currentSession?.startedAt ?? DateTime.now(), endedAt: DateTime.now(), duration: _engine?.elapsed ?? Duration.zero, type: _phase, completed: completed, interrupted: interrupted);
  Future<void> _persistSession(FocusSession session) => _storage.save(session);
  Duration _durationFor(FocusPhase phase) => switch (phase) { FocusPhase.focus => FocusConfig.focusDuration, FocusPhase.shortBreak => FocusConfig.shortBreakDuration, FocusPhase.longBreak => FocusConfig.longBreakDuration };
  int get _notificationId => 700000 + (_currentSession?.id.hashCode ?? _uuid.v4().hashCode).abs() % 100000;
  void _scheduleNotification() { final engine = _engine; if (engine == null || !engine.isRunning || engine.remaining <= Duration.zero) return; unawaited(_notifications.scheduleNotification(_notificationId, _phase == FocusPhase.focus ? 'Focus complete' : 'Break complete', _phase == FocusPhase.focus ? 'Your focus session is complete.' : 'Your break is complete.', DateTime.now().add(engine.remaining), null)); }
  void _rescheduleNotification() { _cancelNotification(); _scheduleNotification(); }
  void _cancelNotification() => unawaited(_notifications.cancelNotification(_notificationId));
  @override
  void dispose() { _cancelNotification(); _completionGuard?.cancel(); _engine?.dispose(); super.dispose(); }
}
