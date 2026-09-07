/// The phases supported by the Focus cycle.
enum FocusPhase {
  focus,
  shortBreak,
  longBreak,
}

extension FocusPhaseX on FocusPhase {
  String get storageValue => switch (this) {
        FocusPhase.focus => 'focus',
        FocusPhase.shortBreak => 'shortBreak',
        FocusPhase.longBreak => 'longBreak',
      };

  static FocusPhase fromStorageValue(String value) {
    return switch (value) {
      'focus' => FocusPhase.focus,
      'shortBreak' => FocusPhase.shortBreak,
      'longBreak' => FocusPhase.longBreak,
      _ => throw ArgumentError.value(value, 'value', 'Unknown FocusPhase'),
    };
  }
}
