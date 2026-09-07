import 'dart:async';

import 'package:flutter/widgets.dart';

/// A lifecycle-aware timer engine whose source of truth is wall-clock
/// timestamps rather than a decrementing counter.
///
/// [Timer.periodic] is used only to notify listeners that the UI should
/// rebuild. The remaining time is always derived from [startedAt],
/// [plannedDuration] and pause timestamps, so the timer remains accurate
/// when Flutter throttles timers in the background.
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
      throw ArgumentError.value(
        plannedDuration,
        'plannedDuration',
        'must be greater than zero',
      );
    }

    WidgetsBinding.instance.addObserver(this);
  }

  static const Duration _tickInterval = Duration(seconds: 1);

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

  /// Time remaining, calculated from timestamps every time it is requested.
  Duration get remaining {
    if (_startedAt == null) return _plannedDuration;
    if (_isCompleted) return Duration.zero;

    final referenceNow = _now();
    final elapsed = _elapsedAt(referenceNow);
    final remainingDuration = _plannedDuration - elapsed;

    if (remainingDuration <= Duration.zero) {
      return Duration.zero;
    }

    return remainingDuration;
  }

  /// Time elapsed in the current session, excluding paused periods.
  Duration get elapsed {
    if (_startedAt == null) return Duration.zero;
    return _elapsedAt(_now());
  }

  double get progress {
    if (_plannedDuration.inMicroseconds <= 0) return 0;

    final value =
        elapsed.inMicroseconds / _plannedDuration.inMicroseconds;
    return value.clamp(0.0, 1.0).toDouble();
  }

  /// Starts a new session or resumes a paused session.
  void start() {
    _assertNotDisposed();

    if (_isRunning || _isCompleted) return;

    final now = _now();

    if (_startedAt == null) {
      _startedAt = now;
      _pausedAccumulated = Duration.zero;
      _pausedAt = null;
    } else if (_pausedAt != null) {
      _pausedAccumulated += now.difference(_pausedAt!);
      _pausedAt = null;
    }

    _isRunning = true;
    _startTicker();
    _tick();
  }

  /// Pauses the current session without losing elapsed time.
  void pause() {
    _assertNotDisposed();

    if (!_isRunning || _startedAt == null) return;

    _pausedAt = _now();
    _isRunning = false;
    _stopTicker();
    _tick();
  }

  /// Resumes a paused session.
  void resume() => start();

  /// Resets the current session to zero elapsed time.
  void reset({Duration? plannedDuration}) {
    _assertNotDisposed();

    _stopTicker();
    _plannedDuration = plannedDuration ?? _plannedDuration;

    if (_plannedDuration <= Duration.zero) {
      throw ArgumentError.value(
        _plannedDuration,
        'plannedDuration',
        'must be greater than zero',
      );
    }

    _startedAt = null;
    _pausedAt = null;
    _pausedAccumulated = Duration.zero;
    _isRunning = false;
    _isCompleted = false;
    _tick();
  }

  /// Changes the duration and resets the session.
  void setDuration(Duration duration) {
    _assertNotDisposed();

    if (duration <= Duration.zero) {
      throw ArgumentError.value(
        duration,
        'duration',
        'must be greater than zero',
      );
    }

    reset(plannedDuration: duration);
  }

  /// Adds time to the current planned duration without changing the
  /// timestamp-based elapsed calculation.
  void addTime(Duration duration) {
    _assertNotDisposed();

    if (duration <= Duration.zero) return;

    _plannedDuration += duration;
    if (_isCompleted) {
      _isCompleted = false;
    }
    _tick();
  }

  /// Immediately evaluates the timer and notifies listeners.
  void refresh() {
    _assertNotDisposed();
    _tick();
  }

  Duration _elapsedAt(DateTime at) {
    final start = _startedAt;
    if (start == null) return Duration.zero;

    final end = _pausedAt ?? at;
    final activeElapsed = end.difference(start) - _pausedAccumulated;

    if (activeElapsed <= Duration.zero) return Duration.zero;
    if (activeElapsed >= _plannedDuration) return _plannedDuration;

    return activeElapsed;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(_tickInterval, (_) => _tick());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _tick() {
    if (_disposed) return;

    final shouldComplete = _isRunning && remaining == Duration.zero;

    if (shouldComplete) {
      _isRunning = false;
      _isCompleted = true;
      _stopTicker();
    }

    _onTick?.call();

    if (shouldComplete) {
      _onCompleted?.call();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;

    // Timer.periodic can be delayed/throttled while the app is backgrounded.
    // Recalculate immediately when the app becomes interactive again.
    if (state == AppLifecycleState.resumed) {
      _tick();
    }
  }

  void _assertNotDisposed() {
    if (_disposed) {
      throw StateError('FocusTimerEngine has already been disposed.');
    }
  }

  void dispose() {
    if (_disposed) return;

    _disposed = true;
    _stopTicker();
    WidgetsBinding.instance.removeObserver(this);
  }
}
