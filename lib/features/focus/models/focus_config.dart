/// Centralized defaults for the Focus system.
///
/// These values are intentionally kept independent from the UI so the
/// provider and future settings can use the same configuration.
class FocusConfig {
  const FocusConfig._();

  static const Duration focusDuration = Duration(minutes: 25);
  static const Duration shortBreakDuration = Duration(minutes: 5);
  static const Duration longBreakDuration = Duration(minutes: 15);
  static const int sessionsBeforeLongBreak = 4;
}
