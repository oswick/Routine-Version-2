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

class _DayScreenState extends State<DayScreen> with AutomaticKeepAliveClientMixin {
  bool _showMorningEvents = true;
  bool _showAfternoonEvents = true;
  bool _showNightEvents = true;

  // Mapa para mantener el estado de los eventos por su ID único
  final Map<String, bool> _eventStates = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeEventStates();
  }

  @override
  void didUpdateWidget(DayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Actualizar estados cuando cambien los eventos
    if (oldWidget.events != widget.events) {
      _initializeEventStates();
    }
  }

  void _initializeEventStates() {
    // Inicializar estados basados en los eventos actuales
    for (var event in widget.events) {
      if (!_eventStates.containsKey(event.id)) {
        _eventStates[event.id] = event.isCompleted;
      } else {
        // Actualizar el estado si ha cambiado en Supabase
        _eventStates[event.id] = event.isCompleted;
      }
    }
    
    // Limpiar estados de eventos que ya no existen
    _eventStates.removeWhere((eventId, _) => 
        !widget.events.any((event) => event.id == eventId));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Necesario para AutomaticKeepAliveClientMixin
    
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
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isVisible ? Icons.expand_less : Icons.expand_more,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(Event event, int index) {
    return Dismissible(
      key: Key('${event.id}_${event.startTime.millisecondsSinceEpoch}'),
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
          key: ValueKey('${event.id}_${event.isCompleted}_${event.startTime.millisecondsSinceEpoch}'),
          event: event,
          onUpdateEvent: (updatedEvent) async {
            // Actualizar el estado local inmediatamente
            setState(() {
              _eventStates[event.id] = updatedEvent.isCompleted;
            });
            
            // Luego actualizar en Supabase
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
          content: Text('Do you want to delete "${event.title}"?'),
          backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          actions: [
            TextButton(
              onPressed: () {
                // Eliminar del estado local
                _eventStates.remove(event.id);
                widget.onDeleteEvent(index, false);
                Navigator.of(context).pop(true);
              },
              child: Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
            if (event.repeatDays.isNotEmpty)
              TextButton(
                onPressed: () {
                  // Eliminar del estado local
                  _eventStates.remove(event.id);
                  widget.onDeleteEvent(index, true);
                  Navigator.of(context).pop(true);
                },
                child: Text(
                  'Delete All Days',
                  style: TextStyle(color: Colors.red),
                ),
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
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: AddEventBottomSheet(
          onAddEvent: (event) {
            // Actualizar estado local
            _eventStates[event.id] = event.isCompleted;
            widget.onAddEvent(event);
            setState(() {}); // Forzar la reconstrucción del widget
          },
          day: widget.day,
        ),
      ),
    );
  }

  void _showEventOptions(BuildContext context, Event event, int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Options for "${event.title}"'),
          backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: AddEventBottomSheet(
                        onAddEvent: (updatedEvent) {
                          // Actualizar estado local
                          _eventStates[updatedEvent.id] = updatedEvent.isCompleted;
                          widget.onUpdateEvent(index, updatedEvent);
                          setState(() {}); // Forzar la reconstrucción del widget
                        },
                        day: widget.day,
                        event: event,
                      ),
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
              child: Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
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

  @override
  void dispose() {
    _eventStates.clear();
    super.dispose();
  }
}