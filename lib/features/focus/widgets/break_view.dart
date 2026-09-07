import 'package:flutter/material.dart';

import '../models/focus_phase.dart';
import 'focus_timer.dart';

class BreakView extends StatelessWidget {
  const BreakView({
    super.key,
    required this.phase,
    required this.remaining,
    required this.progress,
    required this.onStart,
    required this.onSkip,
  });

  final FocusPhase phase;
  final Duration remaining;
  final double progress;
  final VoidCallback onStart;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final title = phase == FocusPhase.longBreak ? 'Long Break' : 'Short Break';
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 28),
        FocusTimer(remaining: remaining, progress: progress),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: onStart,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Start Break'),
        ),
        TextButton(onPressed: onSkip, child: const Text('Skip')),
      ],
    );
  }
}
