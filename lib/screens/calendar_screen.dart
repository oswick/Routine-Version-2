import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  // Función mejorada para obtener eventos filtrados para un día específico
  List<Event> _getEventsForDay(DateTime day) {
    return widget.events.where((event) {
      // Eventos no recurrentes
      if (event.repeatDays.isEmpty) {
        return isSameDay(event.startTime, day);
      }
      // Eventos recurrentes
      else {
        // Verificamos si el día de la semana coincide
        final bool matchesDayOfWeek = event.repeatDays.contains(day.weekday);

        if (!matchesDayOfWeek) return false;

        // Calculamos la diferencia en días entre la fecha original y el día seleccionado
        final eventStartDate = DateTime(event.startTime.year, event.startTime.month, event.startTime.day);
        final diffDays = day.difference(eventStartDate).inDays;

        // Si el día seleccionado es antes de la fecha de inicio del evento, no mostrar
        if (diffDays < 0) return false;

        // Calculamos cuántas semanas completas han pasado desde la fecha de inicio
        final weeksDifference = (diffDays / 7).floor();
        final expectedDayDifference = weeksDifference * 7;
        final expectedDate = eventStartDate.add(Duration(days: expectedDayDifference));

        // Verificamos si el día seleccionado coincide con esta fecha esperada
        return isSameDay(expectedDate, day);
      }
    }).toList();
  }

  // Función auxiliar para verificar si dos fechas son el mismo día
  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  @override
  Widget build(BuildContext context) {
    // Obtener eventos para el día seleccionado (o lista vacía si no hay día seleccionado)
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
              return isSameDay(_selectedDay!, day);
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
          // Mostrar la fecha seleccionada y la cantidad de eventos
          if (_selectedDay != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Events for ${DateFormat('MMMM d, yyyy').format(_selectedDay!)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${events.length}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
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
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _selectedDay == null
                            ? 'Select a day to view events'
                            : 'No events for this day',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_selectedDay != null) {
            // Mostrar el bottom sheet para añadir un nuevo evento en la fecha seleccionada
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (context) {
                // Aquí podrías usar tu AddEventBottomSheet pasando la fecha seleccionada
                // Por ahora, solo mostraremos un placeholder
                return Container(
                  height: MediaQuery.of(context).size.height * 0.7,
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Add event for ${DateFormat('MMMM d, yyyy').format(_selectedDay!)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            // Aquí integrarías tu AddEventBottomSheet
                            // Por ejemplo:
                            // widget.onAddEvent(Event(
                            //   title: '',
                            //   startTime: DateTime(
                            //     _selectedDay!.year,
                            //     _selectedDay!.month,
                            //     _selectedDay!.day,
                            //     // Alguna hora por defecto
                            //   ),
                            //   // otros campos necesarios
                            // ));
                            Navigator.pop(context);
                          },
                          child: const Text('Create Event'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Icon(
          Icons.add,
          color: Theme.of(context).colorScheme.onPrimary,
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
