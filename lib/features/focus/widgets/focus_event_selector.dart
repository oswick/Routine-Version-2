import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/event_provider.dart';

class FocusEventSelector extends StatelessWidget {
  const FocusEventSelector({super.key, required this.eventId, required this.onChanged});

  final String? eventId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final events = context.watch<EventProvider>().events;
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(value: null, child: Text('Free Focus')),
      ...events.take(30).map(
        (event) => DropdownMenuItem<String?>(
          value: event.id,
          child: Text(event.title, overflow: TextOverflow.ellipsis),
        ),
      ),
    ];
    final validValue = eventId != null && events.any((event) => event.id == eventId) ? eventId : null;

    return DropdownButtonFormField<String?>(
      initialValue: validValue,
      decoration: const InputDecoration(labelText: 'Focus target', border: OutlineInputBorder()),
      items: items,
      onChanged: onChanged,
    );
  }
}
