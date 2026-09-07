import 'package:flutter/material.dart';

import '../models/focus_session.dart';
import '../services/focus_storage_service.dart';

class FocusHistoryScreen extends StatelessWidget {
  const FocusHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sessions = FocusStorageService().getAll();

    return Scaffold(
      appBar: AppBar(title: const Text('Focus History')),
      body: sessions.isEmpty
          ? const Center(child: Text('No focus sessions yet'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final FocusSession session = sessions[index];
                return ListTile(
                  leading: Icon(
                    session.completed ? Icons.check_circle_outline : Icons.pause_circle_outline,
                  ),
                  title: Text(session.type.storageValue),
                  subtitle: Text(
                    '${session.startedAt} · ${session.duration.inMinutes} min',
                  ),
                  trailing: session.eventId == null
                      ? const Text('Free Focus')
                      : Text(session.eventId!),
                );
              },
            ),
    );
  }
}
