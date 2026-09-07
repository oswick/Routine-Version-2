import 'package:flutter/material.dart';

import '../models/event.dart';
import '../features/focus/screens/focus_screen.dart';

/// Backward-compatible entry point for existing callers.
/// The timer implementation now lives entirely in the Focus feature.
class PomodoroScreen extends StatelessWidget {
  const PomodoroScreen({super.key, required this.event, this.onAmoledModeChanged});

  final Event event;
  final Function(bool)? onAmoledModeChanged;

  @override
  Widget build(BuildContext context) => FocusScreen(initialEventId: event.id);
}
