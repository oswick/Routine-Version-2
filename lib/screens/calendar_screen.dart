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
    required this.onDeleteEvent,
    required bool fromHomeScreen,
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
        elevation: 0,
        title: Text(
          'Calendar',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          TableCalendar(
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              leftChevronIcon: Icon(
                Icons.chevron_left,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              rightChevronIcon: Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            calendarStyle: CalendarStyle(
              defaultTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              weekendTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              selectedTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              todayDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
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
                  return Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
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
                    padding: const EdgeInsets.all(8.0),
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Dismissible(
                          key: Key(event.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20.0),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            bool? result = await _showDeleteConfirmationDialog(
                              context,
                              event,
                            );
                            if (result == null || !result) {
                              setState(() {});
                            }
                            return result;
                          },
                          onDismissed: (direction) {},
                          child: EventCard(
                            event: event,
                            onUpdateEvent: (updatedEvent) {
                              widget.onUpdateEvent(
                                widget.events.indexOf(event),
                                updatedEvent,
                              );
                              setState(() {});
                            },
                          ),
                        ),
                      );
                    },
                  )
                : Center(
                    child: Text(
                      'Select a day to view events',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.primary,
        onPressed: () {
          if (_selectedDay != null) {
            _showAddEventBottomSheet();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Please select a day on the calendar to add an event',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        child: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
      ),
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
            widget.onAddEvent(event);
            setState(() {});
          },
          day: _selectedDay!,
        ),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmationDialog(
    BuildContext context,
    Event event,
  ) {
    final index = widget.events.indexOf(event);
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Delete Event'),
          content: const Text(
            'Do you want to delete this event? This action cannot be undone.',
          ),
          backgroundColor: Theme.of(context).colorScheme.surface,
          actions: [
            TextButton(
              onPressed: () {
                widget.onDeleteEvent(index, false);
                Navigator.of(context).pop(true);
              },
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
            if (event.repeatDays.isNotEmpty)
              TextButton(
                onPressed: () {
                  widget.onDeleteEvent(index, true);
                  Navigator.of(context).pop(true);
                },
                child: Text('All Days', style: TextStyle(color: Colors.red)),
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
