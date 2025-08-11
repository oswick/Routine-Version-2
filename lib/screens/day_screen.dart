// lib/screens/day_screen.dart - Versión mejorada
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/event_provider.dart';
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

  @override
  bool get wantKeepAlive => true;

  bool _isEventPast(Event event) {
    final now = DateTime.now();
    final selectedDay = DateTime(widget.day.year, widget.day.month, widget.day.day);
    final today = DateTime(now.year, now.month, now.day);
    
    if (event.repeatDays.isNotEmpty) {
      if (widget.day.weekday == now.weekday && selectedDay.isAtSameMomentAs(today)) {
        if (event.endTime != null) {
          final todayEndTime = DateTime(now.year, now.month, now.day, 
              event.endTime!.hour, event.endTime!.minute);
          return now.isAfter(todayEndTime);
        } else {
          final todayStartTime = DateTime(now.year, now.month, now.day, 
              event.startTime.hour, event.startTime.minute);
          return now.isAfter(todayStartTime.add(const Duration(hours: 1)));
        }
      } else {
        return selectedDay.isBefore(today) && event.repeatDays.contains(widget.day.weekday);
      }
    } else {
      if (event.endTime != null) {
        return now.isAfter(event.endTime!);
      } else {
        return now.isAfter(event.startTime.add(const Duration(hours: 1)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

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

    return Consumer<EventProvider>(
      builder: (context, eventProvider, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: eventProvider.isLoading && widget.events.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    if (morningEvents.isNotEmpty) ...[
                      _buildHeader('Morning', _showMorningEvents, () {
                        setState(() {
                          _showMorningEvents = !_showMorningEvents;
                        });
                      }),
                      if (_showMorningEvents)
                        ...morningEvents.map((event) => _buildEventCard(event, eventProvider)),
                    ],
                    if (afternoonEvents.isNotEmpty) ...[
                      _buildHeader('Afternoon', _showAfternoonEvents, () {
                        setState(() {
                          _showAfternoonEvents = !_showAfternoonEvents;
                        });
                      }),
                      if (_showAfternoonEvents)
                        ...afternoonEvents.map((event) => _buildEventCard(event, eventProvider)),
                    ],
                    if (nightEvents.isNotEmpty) ...[
                      _buildHeader('Night', _showNightEvents, () {
                        setState(() {
                          _showNightEvents = !_showNightEvents;
                        });
                      }),
                      if (_showNightEvents)
                        ...nightEvents.map((event) => _buildEventCard(event, eventProvider)),
                    ],
                    if (widget.events.isEmpty) ...[
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 50.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.event_busy,
                                size: 64,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No events for this day',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap the + button to add your first event',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
      },
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

  // MÉTODO CORREGIDO: Mejor gestión de keys para evitar reconstrucciones
  Widget _buildEventCard(Event event, EventProvider eventProvider) {
    final isPastEvent = _isEventPast(event);
    
    // Crear una key estable que no cambie con cada actualización
    final stableKey = ValueKey('event_${event.id}_${widget.day.millisecondsSinceEpoch}');
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Dismissible(
        key: Key('dismissible_${event.id}_${event.startTime.millisecondsSinceEpoch}'),
        direction: DismissDirection.endToStart,
        background: Container(
          color: Colors.red,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20.0),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        confirmDismiss: (direction) async {
          return await _showDeleteConfirmationDialog(context, event, eventProvider);
        },
        onDismissed: (direction) {},
        child: EventCard(
          key: stableKey, // Key estable
          event: event,
          pastEvent: isPastEvent,
          onUpdateEvent: (updatedEvent) async {
            // Actualización optimista sin recargar
            await eventProvider.updateEvent(updatedEvent);
          },
        ),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmationDialog(
    BuildContext context, 
    Event event, 
    EventProvider eventProvider
  ) {
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
              onPressed: () async {
                await eventProvider.deleteEvent(event.id, deleteAll: false);
                Navigator.of(context).pop(true);
              },
              child: Text(
                'Delete',
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
            widget.onAddEvent(event);
          },
          day: widget.day,
        ),
      ),
    );
  }
}