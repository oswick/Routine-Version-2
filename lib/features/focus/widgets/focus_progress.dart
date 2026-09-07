import 'package:flutter/material.dart';

class FocusProgress extends StatelessWidget {
  const FocusProgress({super.key, required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: progress.clamp(0.0, 1.0),
      minHeight: 6,
      borderRadius: BorderRadius.circular(999),
    );
  }
}
