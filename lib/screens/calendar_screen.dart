// lib/screens/calendar_screen.dart - MEJORADA CON TIMELINE Y PREVIEW
import 'package:flutter/material.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:myapp/providers/event_provider.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../widgets/event_card.dart';
import '../widgets/event_preview_sheet.dart';

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
  bool _showTimeline = true;
  final bool _showCompletedEvents = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
  }

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

  List<Event> _getEventsForMarker(DateTime day, List<Event> allEvents) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayToCheck = DateTime(day.year, day.month, day.day);

    if (dayToCheck.isBefore(today)) {
      return [];
    }

    return allEvents.where((event) {
      if (event.repeatDays.isNotEmpty) {
        return false;
      }
      return isSameDay(event.startTime, day);
    }).toList();
  }

  String _getDayType(DateTime selectedDay) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );

    if (selected.isBefore(today)) {
      return 'past';
    } else if (selected.isAtSameMomentAs(today)) {
      return 'today';
    } else {
      return 'future';
    }
  }

  String _getSectionTitle(BuildContext context, String dayType, bool isPast) {
    final l10n = AppLocalizations.of(context);

    if (dayType == 'today') {
      return isPast ? l10n.earlierToday : l10n.todaysEvents;
    } else if (dayType == 'past') {
      return isPast ? l10n.pastEvents : l10n.pastEvents;
    } else {
      return isPast ? l10n.pastEvents : l10n.upcomingEvents;
    }
  }

  void _goToToday() {
    setState(() {
      _selectedDay = DateTime.now();
      _focusedDay = DateTime.now();
    });
  }

  void _toggleCalendarFormat() {
    setState(() {
      _calendarFormat = _calendarFormat == CalendarFormat.month
          ? CalendarFormat.week
          : CalendarFormat.month;
    });
  }

  void _toggleTimeline() {
    setState(() {
      _showTimeline = !_showTimeline;
    });
  }


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Consumer<EventProvider>(
      builder: (context, eventProvider, child) {
        final allEvents = eventProvider.events;
        final events = _selectedDay != null
            ? _getEventsForDay(_selectedDay!, allEvents)
            : [];
        
        // Filtrar eventos completados si está deshabilitado
        final filteredEvents = _showCompletedEvents 
            ? events 
            : events.where((e) => !e.isCompleted).toList();
        
        filteredEvents.sort((a, b) => a.startTime.compareTo(b.startTime));

        final now = DateTime.now();
        final dayType = _selectedDay != null
            ? _getDayType(_selectedDay!)
            : 'today';

        List<Event> pastEvents = [];
        List<Event> currentOrFutureEvents = [];

        if (dayType == 'today') {
          pastEvents = filteredEvents
              .where((e) => e.endTime != null && e.endTime!.isBefore(now))
              .cast<Event>()
              .toList();
          currentOrFutureEvents = filteredEvents
              .where((e) => e.endTime == null || e.endTime!.isAfter(now))
              .cast<Event>()
              .toList();
        } else if (dayType == 'past') {
          pastEvents = filteredEvents.cast<Event>();
          currentOrFutureEvents = [];
        } else {
          pastEvents = [];
          currentOrFutureEvents = filteredEvents.cast<Event>();
        }

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 0,
            title: Text(
              l10n.calendar,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              // Filtrar completados
         
              // Timeline toggle
              IconButton(
                icon: Icon(
                  _showTimeline ? Icons.timeline : Icons.timeline_outlined,
                  color: _showTimeline 
                      ? Theme.of(context).colorScheme.primary 
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
                onPressed: _toggleTimeline,
                tooltip: _showTimeline ? 'Hide timeline' : 'Show timeline',
              ),
              
              // Ir a hoy
              IconButton(
                icon: Icon(
                  Icons.today,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: _goToToday,
                tooltip: 'Today',
              ),
              
              // Cambiar formato
              IconButton(
                icon: Icon(
                  _calendarFormat == CalendarFormat.month
                      ? Icons.view_week
                      : Icons.calendar_month,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
                onPressed: _toggleCalendarFormat,
                tooltip: _calendarFormat == CalendarFormat.month
                    ? 'Week view'
                    : 'Month view',
              ),
            ],
          ),
          body: eventProvider.isLoading && allEvents.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // Calendario
                    TableCalendar(
                      locale: Localizations.localeOf(context).toLanguageTag(),
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
                        return _getEventsForMarker(day, allEvents);
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

                    // Divider
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
                    ),

                    // Selected date info
                    if (_selectedDay != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        color: Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.3),
                        child: Row(
                          children: [
                            Icon(
                              Icons.event,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat.yMMMMd().format(_selectedDay!),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${filteredEvents.length} ${filteredEvents.length == 1 ? 'event' : 'events'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Lista de eventos
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => eventProvider.loadEvents(),
                        child: filteredEvents.isEmpty
                            ? _buildEmptyState(context)
                            : _showTimeline
                                ? _buildTimelineView(
                                    context,
                                    currentOrFutureEvents,
                                    pastEvents,
                                    dayType,
                                    eventProvider,
                                  )
                                : _buildListView(
                                    context,
                                    currentOrFutureEvents,
                                    pastEvents,
                                    dayType,
                                    eventProvider,
                                  ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).noEvents,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineView(
    BuildContext context,
    List<Event> currentOrFutureEvents,
    List<Event> pastEvents,
    String dayType,
    EventProvider eventProvider,
  ) {
    final allEventsForTimeline = [...currentOrFutureEvents, ...pastEvents];
    allEventsForTimeline.sort((a, b) => a.startTime.compareTo(b.startTime));

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: allEventsForTimeline.length,
      itemBuilder: (context, index) {
        final event = allEventsForTimeline[index];
        final isLast = index == allEventsForTimeline.length - 1;
        final isPast = pastEvents.contains(event);

        return _buildTimelineEventCard(
          context,
          event,
          eventProvider,
          isLast,
          isPast,
        );
      },
    );
  }

  Widget _buildTimelineEventCard(
    BuildContext context,
    Event event,
    EventProvider eventProvider,
    bool isLast,
    bool isPast,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline indicator
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isPast
                    ? Colors.grey
                    : Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2,
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 80,
                color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
              ),
          ],
        ),

        const SizedBox(width: 16),

        // Event card
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time label
                Text(
                  DateFormat.jm().format(event.startTime),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isPast
                        ? Colors.grey
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Event card con Dismissible
                Dismissible(
                  key: Key(event.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20.0),
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
                  child: GestureDetector(
                    onTap: () => _showEventPreview(context, event),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          // Category icon
                          if (event.category.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getCategoryIcon(event.category),
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          
                          const SizedBox(width: 12),
                          
                          // Event info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.title,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                if (event.description != null &&
                                    event.description!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      event.description!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface.withOpacity(0.6),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          
                          // Importance indicator
                          if (event.importance != null && event.importance! > 0)
                            Container(
                              width: 4,
                              height: 32,
                              decoration: BoxDecoration(
                                color: _getImportanceColor(event.importance!),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListView(
    BuildContext context,
    List<Event> currentOrFutureEvents,
    List<Event> pastEvents,
    String dayType,
    EventProvider eventProvider,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        if (currentOrFutureEvents.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              _getSectionTitle(context, dayType, false),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
                fontSize: 16,
              ),
            ),
          ),
          ...currentOrFutureEvents.map(
            (event) => Padding(
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
                    await eventProvider.updateEvent(updatedEvent);
                  },
                ),
              ),
            ),
          ),
        ],
        if (pastEvents.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              _getSectionTitle(context, dayType, true),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ),
          ...pastEvents.map(
            (event) => Padding(
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
                    await eventProvider.updateEvent(updatedEvent);
                  },
                  pastEvent: true,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showEventPreview(BuildContext context, Event event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return EventPreviewSheet(
          event: event,
          onEdit: () {
            // Implementar edición si es necesario
          },
          onDelete: () {
            // El delete se maneja dentro del EventPreviewSheet
          },
        );
      },
    );
  }

  Future<bool?> _showDeleteConfirmationDialog(
    BuildContext context,
    Event event,
    EventProvider eventProvider,
  ) {
    final l10n = AppLocalizations.of(context);

    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(l10n.deleteConfirmationTitle),
          content: Text(l10n.deleteConfirmation),
          backgroundColor: Theme.of(context).colorScheme.surface,
          actions: [
            TextButton(
              onPressed: () async {
                await eventProvider.deleteEvent(event.id, deleteAll: false);
                Navigator.of(context).pop(true);
              },
              child: Text(
                l10n.delete,
                style: TextStyle(color: Colors.red),
              ),
            ),
            if (event.repeatDays.isNotEmpty)
              TextButton(
                onPressed: () async {
                  await eventProvider.deleteEvent(event.id, deleteAll: true);
                  Navigator.of(context).pop(true);
                },
                child: Text(
                  l10n.deleteAll,
                  style: TextStyle(color: Colors.red),
                ),
              ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text(l10n.cancel),
            ),
          ],
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'School':
        return Icons.school;
      case 'Home':
        return Icons.home;
      case 'Work':
        return Icons.work;
      case 'Shopping':
        return Icons.shopping_cart;
      case 'Health':
        return Icons.health_and_safety;
      case 'Personal':
        return Icons.person;
      default:
        return Icons.event;
    }
  }

  Color _getImportanceColor(int importance) {
    switch (importance) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.yellow;
      case 3:
        return Colors.orange;
      case 4:
        return Colors.red;
      default:
        return Colors.transparent;
    }
  }
}