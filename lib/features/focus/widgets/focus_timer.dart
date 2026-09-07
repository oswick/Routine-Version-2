import 'package:flutter/material.dart';

class FocusTimer extends StatelessWidget {
  const FocusTimer({
    super.key,
    required this.remaining,
    required this.progress,
    this.large = false,
  });

  final Duration remaining;
  final double progress;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final minutes = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    final text = '$minutes:$seconds';
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: 'Focus timer, $text remaining',
      value: '${(progress * 100).round()} percent',
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: large ? 280 : 220,
            height: large ? 280 : 220,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: large ? 10 : 8,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
          Text(
            text,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: large ? 64 : 52,
                  fontWeight: FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
        ],
      ),
    );
  }
}
