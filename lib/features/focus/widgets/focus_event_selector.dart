import 'package:flutter/material.dart';

class FocusEventSelector extends StatelessWidget {
  const FocusEventSelector({
    super.key,
    required this.eventId,
    required this.onChanged,
  });

  final String? eventId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: eventId,
      decoration: const InputDecoration(
        labelText: 'Focus target',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem<String?>(
          value: null,
          child: Text('Free Focus'),
        ),
      ],
      onChanged: onChanged,
    );
  }
}
