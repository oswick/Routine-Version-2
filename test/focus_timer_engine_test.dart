import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/features/focus/services/focus_timer_engine.dart';

void main() {
  test('remaining is derived from timestamps and planned duration', () {
    var now = DateTime(2026, 9, 7, 8, 0);
    final engine = FocusTimerEngine(
      plannedDuration: const Duration(minutes: 25),
      now: () => now,
    );

    expect(engine.remaining, const Duration(minutes: 25));
    engine.start();
    now = now.add(const Duration(minutes: 10));
    expect(engine.elapsed, const Duration(minutes: 10));
    expect(engine.remaining, const Duration(minutes: 15));
    engine.dispose();
  });

  test('paused time is excluded after resume', () {
    var now = DateTime(2026, 9, 7, 8, 0);
    final engine = FocusTimerEngine(
      plannedDuration: const Duration(minutes: 25),
      now: () => now,
    );

    engine.start();
    now = now.add(const Duration(minutes: 5));
    engine.pause();
    now = now.add(const Duration(minutes: 20));
    expect(engine.elapsed, const Duration(minutes: 5));

    engine.resume();
    now = now.add(const Duration(minutes: 5));
    expect(engine.elapsed, const Duration(minutes: 10));
    expect(engine.remaining, const Duration(minutes: 15));
    engine.dispose();
  });
}
