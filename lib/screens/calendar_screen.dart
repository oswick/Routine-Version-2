// lib/screens/calendar_screen.dart - Versión corregida
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:myapp/providers/event_provider.dart';
import '../models/event.dart';
import '../widgets/event_card.dart';

class MonthlyCalendarScreen extends StatefulWidget {
  final bool fromHomeScreen;
  final Function(Event) onAddEvent;
  final Function(int, Event) onUpdateEvent;
  final List<Event> events;
  final Function(int, bool) onDeleteEvent;

  const MonthlyCalendarScreen({
    super.key,
    required this.fromHomeScreen,
    required this.onAddEvent,
    required this.onUpdateEvent,
    required this.events,
    required this.onDeleteEvent,
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
    _selectedDay = DateTime.now();
  }


  // MÉTODO CORREGIDO: Filtrar eventos para un día específico
  List<Event> _getEventsForDay(DateTime day, List<Event> allEvents) {
    return allEvents.where((event) {
      if (event.repeatDays.isNotEmpty) {
        final eventCreationDate = DateTime(
          event.startTime.year,
          event.startTime.month,
          event.startTime.day,
        );
        final queryDate = DateTime(day.year, day.month, day.day);
        return event.repeatDays.contains(day.weekday) &&
            (queryDate.isAtSameMomentAs(eventCreationDate) ||
                queryDate.isAfter(eventCreationDate));
      } else {
        return isSameDay(event.startTime, day);
      }
    }).toList();
  }

  // MÉTODO NUEVO: Filtrar solo eventos únicos (no repetitivos) para mostrar indicadores
  List<Event> _getSingleEventsForDay(DateTime day, List<Event> allEvents) {
    return allEvents.where((event) {
      // Solo eventos únicos (sin repeatDays)
      return event.repeatDays.isEmpty && isSameDay(event.startTime, day);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EventProvider>(
      builder: (context, eventProvider, child) {
        final allEvents = eventProvider.events;
        final events = _selectedDay != null
            ? _getEventsForDay(_selectedDay!, allEvents)
            : [];
        events.sort((a, b) => a.startTime.compareTo(b.startTime));

        final now = DateTime.now();
        final pastEvents = events
            .where((e) => e.endTime != null && e.endTime!.isBefore(now))
            .toList();
        final futureEvents = events
            .where((e) => e.endTime == null || e.endTime!.isAfter(now))
            .toList();

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 0,
            title: Text(
              'Calendar',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: eventProvider.isLoading && allEvents.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : Column(
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
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        selectedTextStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                        todayDecoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.2),
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
  return _getSingleEventsForDay(day, allEvents);
},
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, date, events) {
                          if (events.isNotEmpty) {
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
                      child: RefreshIndicator(
                        onRefresh: () => eventProvider.loadEvents(),
                        child: ListView(
                          padding: const EdgeInsets.all(8.0),
                          children: [
                            if (futureEvents.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                child: Text(
                                  'Next Events',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              ...futureEvents.map(
                                (event) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4.0,
                                  ),
                                  child: Dismissible(
                                    key: Key(event.id),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      color: Colors.red,
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(
                                        right: 20.0,
                                      ),
                                      child: const Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                      ),
                                    ),
                                    confirmDismiss: (direction) async {
                                      return await _showDeleteConfirmationDialog(
                                        context,
                                        event,
                                        eventProvider,
                                      );
                                    },
                                    onDismissed: (direction) {},
                                    child: EventCard(
                                      event: event,
                                      onUpdateEvent: (updatedEvent) async {
                                        await eventProvider.updateEvent(
                                          updatedEvent,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            if (pastEvents.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                child: Text(
                                  'Past Events',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              ...pastEvents.map(
                                (event) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4.0,
                                  ),
                                  child: Dismissible(
                                    key: Key(event.id),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      color: Colors.red,
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(
                                        right: 20.0,
                                      ),
                                      child: const Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                      ),
                                    ),
                                    confirmDismiss: (direction) async {
                                      return await _showDeleteConfirmationDialog(
                                        context,
                                        event,
                                        eventProvider,
                                      );
                                    },
                                    onDismissed: (direction) {},
                                    child: EventCard(
                                      event: event,
                                      onUpdateEvent: (updatedEvent) async {
                                        await eventProvider.updateEvent(
                                          updatedEvent,
                                        );
                                      },
                                      pastEvent: true,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            if (events.isEmpty) ...[
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 32.0),
                                  child: Text(
                                    'No Events',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.6),
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Future<bool?> _showDeleteConfirmationDialog(
    BuildContext context,
    Event event,
    EventProvider eventProvider,
  ) {
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
              onPressed: () async {
                await eventProvider.deleteEvent(event.id, deleteAll: false);
                Navigator.of(context).pop(true);
              },
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
            if (event.repeatDays.isNotEmpty)
              TextButton(
                onPressed: () async {
                  await eventProvider.deleteEvent(event.id, deleteAll: true);
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

