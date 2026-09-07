import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

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
  FocusPhase _phase = FocusPhase.focus;
  int _completedFocusSessions = 0;
  FocusSession? _currentSession;
  Timer? _completionGuard;

  FocusState get state => _state;
  FocusTimerEngine? get timer => _engine;
  String? get eventId => _eventId;
  FocusPhase get phase => _phase;
  int get completedFocusSessions => _completedFocusSessions;
  FocusSession? get currentSession => _currentSession;
  Duration get remaining => _engine?.remaining ?? _durationFor(_phase);
  Duration get elapsed => _engine?.elapsed ?? Duration.zero;
  double get progress => _engine?.progress ?? 0;
  bool get isRunning => _engine?.isRunning ?? false;

  void selectEvent(String? eventId) {
    if (_engine?.isRunning == true) return;
    _eventId = eventId;
    _state = FocusReady(eventId: eventId);
    notifyListeners();
  }

  void startFocus() => _startPhase(FocusPhase.focus);

  void startBreak() {
    if (_phase == FocusPhase.focus) return;
    _startPhase(_phase);
  }

  /// Starts the correct next phase in the standard Pomodoro cycle.
  void startNextPhase() {
    if (_phase == FocusPhase.focus) {
      final isLong = _completedFocusSessions % FocusConfig.sessionsBeforeLongBreak == 0;
      _startPhase(isLong ? FocusPhase.longBreak : FocusPhase.shortBreak);
    } else {
      _startPhase(FocusPhase.focus);
    }
  }

  void pause() {
    _engine?.pause();
    _rescheduleNotification();
    notifyListeners();
  }

  void resume() {
    _engine?.resume();
    _scheduleNotification();
    notifyListeners();
  }

  void reset() {
    _cancelNotification();
    _engine?.dispose();
    _engine = null;
    _completionGuard?.cancel();
    _completionGuard = null;
    _currentSession = null;
    _phase = FocusPhase.focus;
    _state = FocusReady(eventId: _eventId);
    notifyListeners();
  }

  void addFiveMinutes() {
    _engine?.addTime(const Duration(minutes: 5));
    _rescheduleNotification();
    notifyListeners();
  }

  void finishEarly() {
    final engine = _engine;
    if (engine == null || (!engine.isRunning && engine.elapsed == Duration.zero)) return;
    engine.pause();
    _cancelNotification();
    final session = _buildSession(completed: false, interrupted: true);
    _currentSession = session;
    unawaited(_persistSession(session));
    _state = FocusCompleted(phase: _phase, session: session);
    notifyListeners();
  }

  void skipBreak() {
    if (_phase == FocusPhase.focus) return;
    _cancelNotification();
    _engine?.dispose();
    _engine = null;
    _phase = FocusPhase.focus;
    _state = FocusReady(eventId: _eventId);
    notifyListeners();
  }

  void _startPhase(FocusPhase phase) {
    _cancelNotification();
    _engine?.dispose();
    _completionGuard?.cancel();
    _phase = phase;
    _engine = FocusTimerEngine(
      plannedDuration: _durationFor(phase),
      onTick: notifyListeners,
      onCompleted: _handleTimerCompleted,
    );
    if (phase == FocusPhase.focus) {
      _currentSession = FocusSession(
        id: _uuid.v4(), eventId: _eventId, startedAt: DateTime.now(),
        duration: _durationFor(phase), type: phase,
      );
      _state = FocusActive(eventId: _eventId, phase: phase);
    } else {
      _state = FocusBreak(phase: phase);
    }
    _engine!.start();
    _scheduleNotification();
    notifyListeners();
  }

  void _handleTimerCompleted() {
    if (_engine == null || _completionGuard != null) return;
    _cancelNotification();
    _completionGuard = Timer(const Duration(milliseconds: 50), () {
      _completionGuard = null;
      if (_phase == FocusPhase.focus) {
        _completedFocusSessions++;
        final session = _buildSession(completed: true, interrupted: false);
        _currentSession = session;
        unawaited(_persistSession(session));
      }
      final session = _phase == FocusPhase.focus
          ? _currentSession!
          : FocusSession(
              id: _uuid.v4(), eventId: _eventId,
              startedAt: DateTime.now().subtract(_durationFor(_phase)),
              endedAt: DateTime.now(), duration: _durationFor(_phase),
              type: _phase, completed: true,
            );
      _state = FocusCompleted(phase: _phase, session: session);
      notifyListeners();
    });
  }

  FocusSession _buildSession({required bool completed, required bool interrupted}) {
    final existing = _currentSession;
    return FocusSession(
      id: existing?.id ?? _uuid.v4(), eventId: _eventId,
      startedAt: existing?.startedAt ?? DateTime.now(), endedAt: DateTime.now(),
      duration: _engine?.elapsed ?? Duration.zero, type: _phase,
      completed: completed, interrupted: interrupted,
    );
  }

  int get _notificationId => 700000 + (_currentSession?.id.hashCode ?? _uuid.v4().hashCode).abs() % 100000;

  void _scheduleNotification() {
    final engine = _engine;
    if (engine == null || !engine.isRunning || engine.remaining <= Duration.zero) return;
    final when = DateTime.now().add(engine.remaining);
    unawaited(_notifications.scheduleNotification(
      _notificationId,
      _phase == FocusPhase.focus ? 'Focus complete' : 'Break complete',
      _phase == FocusPhase.focus ? 'Your focus session is complete.' : 'Your break is complete.',
      when,
      null,
    ));
  }

  void _rescheduleNotification() {
    _cancelNotification();
    _scheduleNotification();
  }

  void _cancelNotification() {
    unawaited(_notifications.cancelNotification(_notificationId));
  }

  Future<void> _persistSession(FocusSession session) => _storage.save(session);

  Duration _durationFor(FocusPhase phase) => switch (phase) {
    FocusPhase.focus => FocusConfig.focusDuration,
    FocusPhase.shortBreak => FocusConfig.shortBreakDuration,
    FocusPhase.longBreak => FocusConfig.longBreakDuration,
  };

  @override
  void dispose() {
    _cancelNotification();
    _completionGuard?.cancel();
    _engine?.dispose();
    super.dispose();
  }
}
