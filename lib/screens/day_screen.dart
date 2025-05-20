import 'package:flutter/material.dart';
import 'package:myapp/screens/add_event_screen.dart';
import '../models/event.dart';
import '../widgets/event_card.dart';

class DayScreen extends StatefulWidget {
  final DateTime day;
  final List<Event> events;
  final Function(Event) onAddEvent;
  final Function(int, Event) onUpdateEvent;
  final Function(int, bool) onDeleteEvent;

  const DayScreen({
    super.key,
    required this.day,
    required this.events,
    required this.onAddEvent,
    required this.onUpdateEvent,
    required this.onDeleteEvent,
  });

  @override
  // ignore: library_private_types_in_public_api
  _DayScreenState createState() => _DayScreenState();
}

class _DayScreenState extends State<DayScreen> {
  bool _showMorningEvents = true;
  bool _showAfternoonEvents = true;
  bool _showNightEvents = true;

  @override
  Widget build(BuildContext context) {
    // Group events by time of day
    List<Event> morningEvents = [];
    List<Event> afternoonEvents = [];
    List<Event> nightEvents = [];

    for (var event in widget.events) {
      final hour = event.startTime.hour;
      if (hour >= 0 && hour < 12) {
        morningEvents.add(event);
      } else if (hour >= 12 && hour < 18) {
        afternoonEvents.add(event);
      } else {
        nightEvents.add(event);
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: ListView(
        children: [
          if (morningEvents.isNotEmpty) ...[
            _buildHeader('Morning Events', _showMorningEvents, () {
              setState(() {
                _showMorningEvents = !_showMorningEvents;
              });
            }),
            if (_showMorningEvents)
              ...morningEvents.map((event) =>
                  _buildEventCard(event, widget.events.indexOf(event))),
          ],
          if (afternoonEvents.isNotEmpty) ...[
            _buildHeader('Afternoon Events', _showAfternoonEvents, () {
              setState(() {
                _showAfternoonEvents = !_showAfternoonEvents;
              });
            }),
            if (_showAfternoonEvents)
              ...afternoonEvents.map((event) =>
                  _buildEventCard(event, widget.events.indexOf(event))),
          ],
          if (nightEvents.isNotEmpty) ...[
            _buildHeader('Night Events', _showNightEvents, () {
              setState(() {
                _showNightEvents = !_showNightEvents;
              });
            }),
            if (_showNightEvents)
              ...nightEvents.map((event) =>
                  _buildEventCard(event, widget.events.indexOf(event))),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddEventBottomSheet();
        },
        child: const Icon(Icons.add),
      ),
    );
  }


  Widget _buildHeader(String title, bool isVisible, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title),
            Icon(isVisible ? Icons.expand_less : Icons.expand_more),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(Event event, int index) {
    return Dismissible(
      key: Key(event.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        bool? result =
            await _showDeleteConfirmationDialog(context, index, event);
        if (result == null || !result) {
          // Si se cancela la eliminación, forzamos una reconstrucción
          setState(() {});
        }
        return result;
      },
      onDismissed: (direction) {
        // La eliminación ya se ha manejado en confirmDismiss
      },
      child: GestureDetector(
        onLongPress: () {
          _showEventOptions(context, event, index);
        },
        child: EventCard(
          event: event,
          onUpdateEvent: (updatedEvent) {
            widget.onUpdateEvent(index, updatedEvent);
          },
        ),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmationDialog(
      BuildContext context, int index, Event event) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Event'),
          content: const Text('Do you want to delete this event?'),
          backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          actions: [
            TextButton(
              onPressed: () {
                widget.onDeleteEvent(index, false);
                Navigator.of(context).pop(true);
              },
              child: const Text('Delete'),
            ),
            if (event.repeatDays.isNotEmpty)
              TextButton(
                onPressed: () {
                  widget.onDeleteEvent(index, true);
                  Navigator.of(context).pop(true);
                },
                child: const Text('Delete All Days'),
              ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showAddEventBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddEventBottomSheet(
        onAddEvent: (event) {
          widget.onAddEvent(event);
          setState(() {}); // Forzar la reconstrucción del widget
        },
        day: widget.day,
      ),
    );
  }

  void _showEventOptions(BuildContext context, Event event, int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Event Options'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled:
                      true, // Permite que el BottomSheet se ajuste al teclado
                  builder: (context) {
                    return AddEventBottomSheet(
                      onAddEvent: (updatedEvent) {
                        widget.onUpdateEvent(index, updatedEvent);
                        setState(() {}); // Forzar la reconstrucción del widget
                      },
                      day: widget.day,
                      event: event,
                    );
                  },
                );
              },
              child: const Text('Edit'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showDeleteConfirmationDialog(context, index, event);
              },
              child: const Text('Delete'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}
