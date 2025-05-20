import 'package:flutter/material.dart';
import 'package:myapp/screens/add_event_screen.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/event.dart';
import '../widgets/event_card.dart'; // Import the EventCard widget

class MonthlyCalendarScreen extends StatefulWidget {
  final List<Event> events;
  final Function(Event) onAddEvent;
  final Function(int, Event) onUpdateEvent;
  final Function(int, bool) onDeleteEvent;

  const MonthlyCalendarScreen({
    super.key,
    required this.events,
    required this.onAddEvent,
    required this.onUpdateEvent,
    required this.onDeleteEvent, required bool fromHomeScreen,
  });

  @override
  _MonthlyCalendarScreenState createState() => _MonthlyCalendarScreenState();
}

class _MonthlyCalendarScreenState extends State<MonthlyCalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now(); // Seleccionar automáticamente el día actual
  }

  // Función para obtener eventos filtrados para un día específico
  List<Event> _getEventsForDay(DateTime day) {
    return widget.events.where((event) {
      return (isSameDay(event.startTime, day) ||
              event.repeatDays.contains(day.weekday)) &&
          day.isAfter(DateTime.now().subtract(const Duration(days: 1)));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final events = _selectedDay != null ? _getEventsForDay(_selectedDay!) : [];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        title: const Text('Calendar'),
      ),
      body: Column(
        children: [
          TableCalendar(
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            firstDay: DateTime.utc(2010, 10, 16),
            lastDay: DateTime.utc(2030, 3, 14),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            eventLoader: (day) {
              return _getEventsForDay(day);
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                final now = DateTime.now();
                if (events.isNotEmpty &&
                    date.isAfter(now.subtract(const Duration(days: 1)))) {
                  return Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }
                return null;
              },
            ),
          ),
          Expanded(
            child: events.isNotEmpty
                ? ListView.builder(
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
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
                          bool? result = await _showDeleteConfirmationDialog(context, event);
                          if (result == null || !result) {
                            // Si se cancela la eliminación, forzamos una reconstrucción
                            setState(() {});
                          }
                          return result;
                        },
                        onDismissed: (direction) {
                          // La eliminación ya se ha manejado en confirmDismiss
                        },
                        child: EventCard(
                          event: event,
                          onUpdateEvent: (updatedEvent) {
                            widget.onUpdateEvent(widget.events.indexOf(event), updatedEvent);
                            setState(() {}); // Forzar la reconstrucción del widget
                          },
                        ),
                      );
                    },
                  )
                : const Center(child: Text('Select a day to view events')),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_selectedDay != null) {
            _showAddEventBottomSheet();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please select a day on the calendar to add an event'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
        child: const Icon(Icons.add),
      ),
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
        day: _selectedDay!,
      ),
    );
  }

  Future<bool?> _showDeleteConfirmationDialog(BuildContext context, Event event) {
    final index = widget.events.indexOf(event);
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          title: const Text('Delete Event'),
          content: const Text(
              'Do you want to delete this event? This action cannot be undone.'),
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
                child: const Text('All Days'),
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
}
