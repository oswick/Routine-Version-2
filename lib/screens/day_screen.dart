// lib/screens/day_screen.dart - VERSIÓN OPTIMIZADA
import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/components/buttons/enums/m3e_button_enums.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
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
  @override
  bool get wantKeepAlive => true;

  List<Event>? _cachedSortedEvents;
  Map<TimePeriod, List<Event>>? _cachedGroupedEvents;
  EventSortOption? _cachedSortOption;
  int? _cachedEventsHash;

  final Map<TimePeriod, bool> _sectionVisibility = {
    TimePeriod.morning: true,
    TimePeriod.afternoon: true,
    TimePeriod.evening: true,
    TimePeriod.night: true,
  };

  EventSortOption _sortOption = EventSortOption.timeAscending;

  @override
  void initState() {
    super.initState();
    _loadSortPreference();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cachedSortedEvents = null;
    _cachedGroupedEvents = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadSortPreference();
    }
  }

  @override
  void didUpdateWidget(DayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.events != widget.events ||
        !_isSameDay(oldWidget.day, widget.day)) {
      _invalidateCache();
    }
  }

  void _invalidateCache() {
    _cachedSortedEvents = null;
    _cachedGroupedEvents = null;
    _cachedEventsHash = null;
  }

  int _calculateEventsHash(List<Event> events) {
    return events.fold(0, (hash, event) {
      return hash ^ event.id.hashCode ^ event.lastModified.hashCode;
    });
  }

  List<Event> _getCachedSortedEvents() {
    final currentHash = _calculateEventsHash(widget.events);

    if (_cachedSortedEvents == null ||
        _cachedSortOption != _sortOption ||
        _cachedEventsHash != currentHash) {
      _cachedSortedEvents = EventSortingUtils.sortEvents(
        widget.events,
        widget.day,
        sortBy: _sortOption,
      );
      _cachedSortOption = _sortOption;
      _cachedEventsHash = currentHash;
    }

    return _cachedSortedEvents!;
  }

  Map<TimePeriod, List<Event>> _getCachedGroupedEvents() {
    if (_cachedGroupedEvents == null) {
      final sortedEvents = _getCachedSortedEvents();
      _cachedGroupedEvents = EventSortingUtils.groupByTimePeriod(
        sortedEvents,
        widget.day,
        sortGroups: false,
      );
    }
    return _cachedGroupedEvents!;
  }

  Future<void> _loadSortPreference() async {
    final sortOption = await EventSortingUtils.loadSortPreference();
    if (mounted && sortOption != _sortOption) {
      setState(() {
        _sortOption = sortOption;
        _invalidateCache();
      });
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
        return l10n.night;
      case TimePeriod.night:
        // FIX: was hardcoded 'Madrugada' — now uses l10n
        return l10n.earlyMorning;
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final eventsByPeriod = _getCachedGroupedEvents();

    final nonEmptyPeriods = eventsByPeriod.entries
        .where((entry) => entry.value.isNotEmpty)
        .toList();

    return Selector<EventProvider, bool>(
      selector: (_, provider) => provider.isLoading,
      builder: (context, isLoading, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: isLoading && widget.events.isEmpty
              ? const Center(child: M3ELoadingIndicator())
              : widget.events.isEmpty
              ? _buildEmptyState()
              : _buildEventsList(nonEmptyPeriods),
          // DESPUÉS
          floatingActionButton: M3EFab(
            icon: const Icon(Icons.add),
            onPressed: _showAddEventBottomSheet,
          ),
        );
      },
    );
  }

  Widget _buildEventsList(List<MapEntry<TimePeriod, List<Event>>> periods) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: periods.length,
      itemBuilder: (context, index) {
        final entry = periods[index];
        final period = entry.key;
        final events = entry.value;

        return _PeriodSection(
          key: ValueKey('${period.name}_${widget.day.millisecondsSinceEpoch}'),
          period: period,
          periodName: _getPeriodName(period),
          events: events,
          isVisible: _sectionVisibility[period]!,
          onToggleVisibility: () {
            setState(() {
              _sectionVisibility[period] = !_sectionVisibility[period]!;
            });
          },
          day: widget.day,
          isEventPast: _isEventPast,
          onUpdateEvent: widget.onUpdateEvent,
          onDeleteEvent: widget.onDeleteEvent,
        );
      },
    );
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

  void _showAddEventBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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

class _PeriodSection extends StatelessWidget {
  final TimePeriod period;
  final String periodName;
  final List<Event> events;
  final bool isVisible;
  final VoidCallback onToggleVisibility;
  final DateTime day;
  final bool Function(Event) isEventPast;
  final Function(int, Event) onUpdateEvent;
  final Function(int, bool) onDeleteEvent;

  const _PeriodSection({
    super.key,
    required this.period,
    required this.periodName,
    required this.events,
    required this.isVisible,
    required this.onToggleVisibility,
    required this.day,
    required this.isEventPast,
    required this.onUpdateEvent,
    required this.onDeleteEvent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPeriodHeader(context),
        if (isVisible)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: events.length,
            separatorBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 4.0,
              ),
              child: Divider(
                height: 1,
                thickness: 0.5,
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withOpacity(0.3),
              ),
            ),
            itemBuilder: (context, index) {
              final event = events[index];
              return _buildEventCard(context, event, index);
            },
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildPeriodHeader(BuildContext context) {
    return GestureDetector(
      onTap: onToggleVisibility,
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
              periodName,
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
                '${events.length}',
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

  Widget _buildEventCard(BuildContext context, Event event, int index) {
    final isPastEvent = isEventPast(event);
    final stableKey = ValueKey(
      'event_${event.id}_${day.millisecondsSinceEpoch}',
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Dismissible(
        key: Key(
          'dismissible_${event.id}_${event.startTime.millisecondsSinceEpoch}',
        ),
        direction: DismissDirection.endToStart,
        background: Container(
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20.0),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        confirmDismiss: (direction) async {
          return await _showDeleteConfirmationDialog(context, event);
        },
        onDismissed: (direction) {},
        child: EventCard(
          key: stableKey,
          event: event,
          pastEvent: isPastEvent,
          onUpdateEvent: (updatedEvent) async {
            final eventProvider = Provider.of<EventProvider>(
              context,
              listen: false,
            );
            await eventProvider.updateEvent(updatedEvent);
          },
        ),
      ),
    );
  }

 // DESPUÉS
Future<bool?> _showDeleteConfirmationDialog(BuildContext context, Event event) {
  return M3EDialog.show<bool>(
    context,
    dialog: M3EDialog(
      title: AppLocalizations.of(context).deleteConfirmationTitle,
      content: Text('${AppLocalizations.of(context).deleteConfirmation} "${event.title}"?'),
      actions: [
        M3EButton(
          style: M3EButtonStyle.text,
          onPressed: () async {
            final eventProvider = Provider.of<EventProvider>(context, listen: false);
            await eventProvider.deleteEvent(event.id, deleteAll: false);
            Navigator.of(context).pop(true);
          },
          child: Text(AppLocalizations.of(context).delete),
        ),
        if (event.repeatDays.isNotEmpty)
          M3EButton(
            style: M3EButtonStyle.text,
            onPressed: () async {
              final eventProvider = Provider.of<EventProvider>(context, listen: false);
              await eventProvider.deleteEvent(event.id, deleteAll: true);
              Navigator.of(context).pop(true);
            },
            child: Text(AppLocalizations.of(context).deleteAllDays),
          ),
        M3EButton(
          style: M3EButtonStyle.text,
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(AppLocalizations.of(context).cancel),
        ),
      ],
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
}
