import 'package:flutter/material.dart';

import '../models/focus_phase.dart';
import '../services/focus_storage_service.dart';

class FocusStats extends StatelessWidget {
  const FocusStats({super.key});

  @override
  Widget build(BuildContext context) {
    final sessions = FocusStorageService()
        .getForDay(DateTime.now())
        .where((s) => s.type == FocusPhase.focus && s.completed)
        .toList();
    final total = sessions.fold<Duration>(
      Duration.zero,
      (sum, session) => sum + session.duration,
    );
    final hours = total.inHours;
    final minutes = total.inMinutes.remainder(60);
    final duration = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

    return Text(
      'Today · $duration focused · ${sessions.length} ${sessions.length == 1 ? 'session' : 'sessions'}',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}
