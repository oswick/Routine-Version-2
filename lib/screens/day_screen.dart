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

  bool _isEventPast(Event event) {
    final now = DateTime.now();
    final selectedDay = DateTime(widget.day.year, widget.day.month, widget.day.day);
    final today = DateTime(now.year, now.month, now.day);
    
    // Si es un evento repetitivo
    if (event.repeatDays.isNotEmpty) {
      // Verificar si hoy es uno de los días de repetición
      if (widget.day.weekday == now.weekday && selectedDay.isAtSameMomentAs(today)) {
        // Es hoy y es un día de repetición - verificar si la hora ya pasó
        if (event.endTime != null) {
          final todayEndTime = DateTime(now.year, now.month, now.day, 
              event.endTime!.hour, event.endTime!.minute);
          return now.isAfter(todayEndTime);
        } else {
          final todayStartTime = DateTime(now.year, now.month, now.day, 
              event.startTime.hour, event.startTime.minute);
          return now.isAfter(todayStartTime.add(const Duration(hours: 1))); // Asumir 1 hora de duración
        }
      } else {
        // Es un día pasado y es un día de repetición
        return selectedDay.isBefore(today) && event.repeatDays.contains(widget.day.weekday);
      }
    } else {
      // Evento único - verificar si ya pasó completamente
      if (event.endTime != null) {
        return now.isAfter(event.endTime!);
      } else {
        return now.isAfter(event.startTime.add(const Duration(hours: 1))); // Asumir 1 hora de duración
      }
    }
    
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Group events by time of day and separate past events
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
        padding: const EdgeInsets.all(16.0),
        children: [
          if (morningEvents.isNotEmpty) ...[
            _buildHeader('Morning', _showMorningEvents, () {
              setState(() {
                _showMorningEvents = !_showMorningEvents;
              });
            }),
            if (_showMorningEvents)
              ...morningEvents.map((event) => _buildEventCard(event, widget.events.indexOf(event))),
          ],
          if (afternoonEvents.isNotEmpty) ...[
            _buildHeader('Afternoon', _showAfternoonEvents, () {
              setState(() {
                _showAfternoonEvents = !_showAfternoonEvents;
              });
            }),
            if (_showAfternoonEvents)
              ...afternoonEvents.map((event) => _buildEventCard(event, widget.events.indexOf(event))),
          ],
          if (nightEvents.isNotEmpty) ...[
            _buildHeader('Night', _showNightEvents, () {
              setState(() {
                _showNightEvents = !_showNightEvents;
              });
            }),
            if (_showNightEvents)
              ...nightEvents.map((event) => _buildEventCard(event, widget.events.indexOf(event))),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.primary,
        onPressed: _showAddEventBottomSheet,
        child: Icon(
          Icons.add,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }

  Widget _buildHeader(String title, bool isVisible, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
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
    final isPastEvent = _isEventPast(event);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Dismissible(
        key: Key('${event.id}_${event.startTime.millisecondsSinceEpoch}'),
        direction: DismissDirection.endToStart,
        background: Container(
          color: Colors.red,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20.0),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        confirmDismiss: (direction) async {
          bool? result = await _showDeleteConfirmationDialog(context, index, event);
          if (result == null || !result) {
            setState(() {});
          }
          return result;
        },
        onDismissed: (direction) {},
        child: EventCard(
          key: ValueKey('${event.id}_${event.isCompleted}_${event.startTime.millisecondsSinceEpoch}'),
          event: event,
          pastEvent: isPastEvent, // Pasar el flag de evento pasado
          onUpdateEvent: (updatedEvent) async {
            setState(() {
              _eventStates[event.id] = updatedEvent.isCompleted;
            });
            widget.onUpdateEvent(index, updatedEvent);
          },
        ),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmationDialog(BuildContext context, int index, Event event) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('Delete Event'),
          content: Text('Do you want to delete "${event.title}"?'),
          backgroundColor: Theme.of(context).colorScheme.surface,
          actions: [
            TextButton(
              onPressed: () {
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
              child: Text('Cancel'),
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: AddEventBottomSheet(
          onAddEvent: (event) {
            _eventStates[event.id] = event.isCompleted;
            widget.onAddEvent(event);
            setState(() {});
          },
          day: widget.day,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _eventStates.clear();
    super.dispose();
  }
}