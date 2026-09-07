import 'package:flutter/material.dart';

class FocusStats extends StatelessWidget {
  const FocusStats({
    super.key,
    required this.focusedDuration,
    required this.sessions,
  });

  final Duration focusedDuration;
  final int sessions;

  @override
  Widget build(BuildContext context) {
    final hours = focusedDuration.inHours;
    final minutes = focusedDuration.inMinutes.remainder(60);
    final duration = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

    return Text(
      'Today · $duration focused · $sessions ${sessions == 1 ? 'session' : 'sessions'}',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}
