import 'dart:async';
import 'package:flutter/widgets.dart';

class FocusTimerEngine with WidgetsBindingObserver {
  FocusTimerEngine({
    required Duration plannedDuration,
    VoidCallback? onTick,
    VoidCallback? onCompleted,
    DateTime Function()? now,
  })  : _plannedDuration = plannedDuration,
        _onTick = onTick,
        _onCompleted = onCompleted,
        _now = now ?? DateTime.now {
    if (plannedDuration <= Duration.zero) {
      throw ArgumentError.value(plannedDuration, 'plannedDuration', 'must be greater than zero');
    }
    WidgetsBinding.instance.addObserver(this);
  }

  static const _tickInterval = Duration(seconds: 1);
  final VoidCallback? _onTick;
  final VoidCallback? _onCompleted;
  final DateTime Function() _now;
  Timer? _ticker;
  Duration _plannedDuration;
  Duration _pausedAccumulated = Duration.zero;
  DateTime? _startedAt;
  DateTime? _pausedAt;
  bool _isRunning = false;
  bool _isCompleted = false;
  bool _disposed = false;

  Duration get plannedDuration => _plannedDuration;
  Duration get pausedAccumulated => _pausedAccumulated;
  DateTime? get startedAt => _startedAt;
  DateTime? get pausedAt => _pausedAt;
  bool get isRunning => _isRunning;
  bool get isPaused => _startedAt != null && !_isRunning && !_isCompleted;
  bool get isCompleted => _isCompleted;
  Duration get remaining {
    if (_startedAt == null) return _plannedDuration;
    if (_isCompleted) return Duration.zero;
    final value = _plannedDuration - _elapsedAt(_now());
    return value <= Duration.zero ? Duration.zero : value;
  }
  Duration get elapsed => _startedAt == null ? Duration.zero : _elapsedAt(_now());
  double get progress => (_plannedDuration.inMicroseconds == 0 ? 0 : elapsed.inMicroseconds / _plannedDuration.inMicroseconds).clamp(0.0, 1.0).toDouble();

  /// Starts now, or resumes a paused timer.
  void start() => _startAt(_now());

  /// Starts an event timer at its real scheduled start time. If the event is
  /// already in progress, the remaining time is therefore exactly its
  /// scheduled end minus the current wall clock time.
  void startAt(DateTime scheduledStart) {
    _assertNotDisposed();
    if (_isRunning || _isCompleted) return;
    _startAt(scheduledStart);
  }

  void _startAt(DateTime start) {
    _assertNotDisposed();
    if (_isRunning || _isCompleted) return;
    if (_startedAt == null) {
      _startedAt = start;
      _pausedAccumulated = Duration.zero;
      _pausedAt = null;
    } else if (_pausedAt != null) {
      _pausedAccumulated += _now().difference(_pausedAt!);
      _pausedAt = null;
    }
    _isRunning = true;
    _startTicker();
    _tick();
  }

  void pause() {
    _assertNotDisposed();
    if (!_isRunning || _startedAt == null) return;
    _pausedAt = _now();
    _isRunning = false;
    _stopTicker();
    _tick();
  }

  void resume() => start();

  void reset({Duration? plannedDuration}) {
    _assertNotDisposed();
    _stopTicker();
    _plannedDuration = plannedDuration ?? _plannedDuration;
    if (_plannedDuration <= Duration.zero) throw ArgumentError.value(_plannedDuration, 'plannedDuration', 'must be greater than zero');
    _startedAt = null;
    _pausedAt = null;
    _pausedAccumulated = Duration.zero;
    _isRunning = false;
    _isCompleted = false;
    _tick();
  }

  void setDuration(Duration duration) {
    _assertNotDisposed();
    if (duration <= Duration.zero) throw ArgumentError.value(duration, 'duration', 'must be greater than zero');
    reset(plannedDuration: duration);
  }

  void addTime(Duration duration) {
    _assertNotDisposed();
    if (duration <= Duration.zero) return;
    _plannedDuration += duration;
    if (_isCompleted) {
      _isCompleted = false;
      _isRunning = true;
      _pausedAt = null;
      _startTicker();
    }
    _tick();
  }

  void refresh() {
    _assertNotDisposed();
    _tick();
  }

  Duration _elapsedAt(DateTime at) {
    final start = _startedAt;
    if (start == null) return Duration.zero;
    final end = _pausedAt ?? at;
    final value = end.difference(start) - _pausedAccumulated;
    if (value <= Duration.zero) return Duration.zero;
    if (value >= _plannedDuration) return _plannedDuration;
    return value;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(_tickInterval, (_) => _tick());
  }
  void _stopTicker() { _ticker?.cancel(); _ticker = null; }

  void _tick() {
    if (_disposed) return;
    final completed = _isRunning && remaining == Duration.zero;
    if (completed) {
      _isRunning = false;
      _isCompleted = true;
      _stopTicker();
    }
    _onTick?.call();
    if (completed) _onCompleted?.call();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_disposed && state == AppLifecycleState.resumed) _tick();
  }

  void _assertNotDisposed() {
    if (_disposed) throw StateError('FocusTimerEngine has already been disposed.');
  }
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _stopTicker();
    WidgetsBinding.instance.removeObserver(this);
  }
}
