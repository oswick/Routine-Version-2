// lib/screens/day_screen.dart - Con ordenamiento inteligente
import 'package:flutter/material.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/event_provider.dart';
import 'package:myapp/screens/add_event_screen.dart';
import 'package:myapp/utils/event_sorting_utils.dart';
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

class _DayScreenState extends State<DayScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  
  // 🆕 Estado de secciones colapsables
  final Map<TimePeriod, bool> _sectionVisibility = {
    TimePeriod.morning: true,
    TimePeriod.afternoon: true,
    TimePeriod.evening: true,
    TimePeriod.night: true,
  };

  // 🆕 Opción de ordenamiento
  EventSortOption _sortOption = EventSortOption.timeAscending;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadSortPreference();
    WidgetsBinding.instance.addObserver(this); // 🆕 Observar lifecycle
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // 🆕 Remover observer
    super.dispose();
  }

  // 🆕 Detectar cuando la app regresa del background (ej: Settings)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadSortPreference(); // Recargar preferencia cuando regresamos
    }
  }

  // 🆕 Cargar preferencia de ordenamiento al iniciar
  Future<void> _loadSortPreference() async {
    final sortOption = await EventSortingUtils.loadSortPreference();
    if (mounted) {
      setState(() => _sortOption = sortOption);
    }
  }

  bool _isEventPast(Event event) {
    final now = DateTime.now();
    final selectedDay = DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
    );
    final today = DateTime(now.year, now.month, now.day);

    if (event.repeatDays.isNotEmpty) {
      if (widget.day.weekday == now.weekday &&
          selectedDay.isAtSameMomentAs(today)) {
        if (event.endTime != null) {
          final todayEndTime = DateTime(
            now.year,
            now.month,
            now.day,
            event.endTime!.hour,
            event.endTime!.minute,
          );
          return now.isAfter(todayEndTime);
        } else {
          final todayStartTime = DateTime(
            now.year,
            now.month,
            now.day,
            event.startTime.hour,
            event.startTime.minute,
          );
          return now.isAfter(todayStartTime.add(const Duration(hours: 1)));
        }
      } else {
        return selectedDay.isBefore(today) &&
            event.repeatDays.contains(widget.day.weekday);
      }
    } else {
      if (event.endTime != null) {
        return now.isAfter(event.endTime!);
      } else {
        return now.isAfter(event.startTime.add(const Duration(hours: 1)));
      }
    }
  }

  String _getPeriodName(TimePeriod period) {
    final l10n = AppLocalizations.of(context);
    switch (period) {
      case TimePeriod.morning:
        return l10n.morning;
      case TimePeriod.afternoon:
        return l10n.afternoon;
      case TimePeriod.evening:
        return l10n.night; // Reusa "night" para "evening"
      case TimePeriod.night:
        return 'Madrugada'; // Agrega esta traducción si no existe
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // 🆕 Ordenar eventos según la preferencia seleccionada PRIMERO
    final sortedEvents = EventSortingUtils.sortEvents(
      widget.events,
      widget.day,
      sortBy: _sortOption,
    );

    // 🆕 Agrupar por periodo SIN re-ordenar (sortGroups: false)
    final eventsByPeriod = EventSortingUtils.groupByTimePeriod(
      sortedEvents,
      widget.day,
      sortGroups: false, // Mantener el orden ya aplicado
    );

    // Filtrar periodos vacíos
    final nonEmptyPeriods = eventsByPeriod.entries
        .where((entry) => entry.value.isNotEmpty)
        .toList();

    return Consumer<EventProvider>(
      builder: (context, eventProvider, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: eventProvider.isLoading && widget.events.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // 🆕 Barra de opciones de ordenamiento
                
                    
                    Expanded(
                      child: widget.events.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.all(16.0),
                              itemCount: nonEmptyPeriods.length,
                              itemBuilder: (context, index) {
                                final entry = nonEmptyPeriods[index];
                                final period = entry.key;
                                final events = entry.value;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildPeriodHeader(period, events.length),
                                    if (_sectionVisibility[period]!)
                                      ...events.asMap().entries.map((entry) {
                                        final index = entry.key;
                                        final event = entry.value;
                                        final isLast = index == events.length - 1;
                                        
                                        return Column(
                                          children: [
                                            _buildEventCard(event, eventProvider),
                                            // 🆕 Divider sutil entre eventos (excepto el último)
                                            if (!isLast)
                                              Padding(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 16.0,
                                                  vertical: 4.0,
                                                ),
                                                child: Divider(
                                                  height: 1,
                                                  thickness: 0.5,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .outlineVariant
                                                      .withOpacity(0.3),
                                                ),
                                              ),
                                          ],
                                        );
                                      }),
                                    const SizedBox(height: 8),
                                  ],
                                );
                              },
                            ),
                    ),
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

  


  Widget _buildPeriodHeader(TimePeriod period, int eventCount) {
    final isVisible = _sectionVisibility[period]!;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _sectionVisibility[period] = !isVisible;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Icon(
              _getPeriodIcon(period),
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              _getPeriodName(period),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$eventCount',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const Spacer(),
            Icon(
              isVisible ? Icons.expand_less : Icons.expand_more,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPeriodIcon(TimePeriod period) {
    switch (period) {
      case TimePeriod.morning:
        return Icons.wb_sunny;
      case TimePeriod.afternoon:
        return Icons.wb_twilight;
      case TimePeriod.evening:
        return Icons.nightlight;
      case TimePeriod.night:
        return Icons.bedtime;
    }
  }

  Widget _buildEmptyState() {
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
              AppLocalizations.of(context).noEventsForThisDay,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).tapPlusButtonToAddEvent,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(Event event, EventProvider eventProvider) {
    final isPastEvent = _isEventPast(event);
    final stableKey = ValueKey(
      'event_${event.id}_${widget.day.millisecondsSinceEpoch}',
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0), // 🆕 Espaciado entre cards
      child: Dismissible(
        key: Key(
          'dismissible_${event.id}_${event.startTime.millisecondsSinceEpoch}',
        ),
        direction: DismissDirection.endToStart,
        background: Container(
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12), // 🆕 Matching card radius
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20.0),
          child: const Icon(Icons.delete, color: Colors.white),
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
          key: stableKey,
          event: event,
          pastEvent: isPastEvent,
          onUpdateEvent: (updatedEvent) async {
            await eventProvider.updateEvent(updatedEvent);
          },
        ),
      ),
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
          title: Text(AppLocalizations.of(context).deleteConfirmationTitle),
          content: Text(
            '${AppLocalizations.of(context).deleteConfirmation} "${event.title}"?',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await eventProvider.deleteEvent(event.id, deleteAll: false);
                Navigator.of(context).pop(true);
              },
              child: Text(
                AppLocalizations.of(context).delete,
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
                  AppLocalizations.of(context).deleteAllDays,
                  style: TextStyle(color: Colors.red),
                ),
              ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text(AppLocalizations.of(context).cancel),
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