import 'package:flutter/material.dart';

class FocusControls extends StatelessWidget {
  const FocusControls({
    super.key,
    required this.isRunning,
    required this.onStart,
    required this.onPause,
    required this.onFinish,
    required this.onAddTime,
  });

  final bool isRunning;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onFinish;
  final VoidCallback onAddTime;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.icon(
          onPressed: isRunning ? onPause : onStart,
          icon: Icon(isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded),
          label: Text(isRunning ? 'Pause' : 'Start'),
        ),
        OutlinedButton.icon(
          onPressed: onFinish,
          icon: const Icon(Icons.stop_rounded),
          label: const Text('Finish'),
        ),
        IconButton.filledTonal(
          onPressed: onAddTime,
          tooltip: 'Add 5 minutes',
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}
