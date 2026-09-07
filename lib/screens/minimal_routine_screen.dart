import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/event.dart';
import 'package:myapp/providers/event_provider.dart';
import 'package:myapp/screens/calendar_screen.dart';
import 'package:myapp/screens/day_screen.dart';
import 'package:myapp/screens/profile_screen.dart';
import 'package:provider/provider.dart';

/// The primary Routine experience.
///
/// Calendar and profile remain available as temporary sheets, so the app
/// keeps its existing functionality without persistent bottom navigation.
class MinimalRoutineScreen extends StatefulWidget {
  const MinimalRoutineScreen({super.key});

  @override
  State<MinimalRoutineScreen> createState() => _MinimalRoutineScreenState();
}

class _MinimalRoutineScreenState extends State<MinimalRoutineScreen> {
  DateTime _selectedDate = DateTime.now();
  Timer? _clockTimer;

  DateTime get _dayOnly => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );

  @override
  void initState() {
    super.initState();
    _startClock();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  void _startClock() {
    // Keeps the single-screen timeline aware of time passing. This is
    // intentionally lightweight; EventCard owns its per-second progress
    // animation while this timer handles transitions such as upcoming -> now
    // and now -> past.
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;

      final now = DateTime.now();
      final currentDay = DateTime(now.year, now.month, now.day);

      if (_dayOnly == currentDay) {
        setState(() {});
      }
    });
  }

  void _changeDay(int amount) {
    setState(() {
      _selectedDate = _dayOnly.add(Duration(days: amount));
    });
  }

  void _goToToday() {
    setState(() {
      _selectedDate = DateTime.now();
    });
  }

  String _dayName(BuildContext context, DateTime date) {
    final l10n = AppLocalizations.of(context);
    switch (date.weekday) {
      case DateTime.monday:
        return l10n.monday;
      case DateTime.tuesday:
        return l10n.tuesday;
      case DateTime.wednesday:
        return l10n.wednesday;
      case DateTime.thursday:
        return l10n.thursday;
      case DateTime.friday:
        return l10n.friday;
      case DateTime.saturday:
        return l10n.saturday;
      case DateTime.sunday:
        return l10n.sunday;
      default:
        return '';
    }
  }

  bool get _isToday {
    final now = DateTime.now();
    return _dayOnly == DateTime(now.year, now.month, now.day);
  }

  Future<void> _showCalendar() async {
    final provider = Provider.of<EventProvider>(context, listen: false);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          height: MediaQuery.sizeOf(sheetContext).height * 0.92,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Theme.of(sheetContext).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: MonthlyCalendarScreen(
            fromHomeScreen: true,
            events: provider.events,
            onAddEvent: provider.addEvent,
            onUpdateEvent: (index, event) => provider.updateEvent(event),
            onDeleteEvent: (index, deleteAll) async {
              if (index < 0 || index >= provider.events.length) return;
              await provider.deleteEvent(
                provider.events[index].id,
                deleteAll: deleteAll,
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showProfile() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          height: MediaQuery.sizeOf(sheetContext).height * 0.92,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Theme.of(sheetContext).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: const ProfileScreen(),
        );
      },
    );
  }

  void _showMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        final l10n = AppLocalizations.of(sheetContext);

        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: Text(l10n.calendar),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showCalendar();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(l10n.profile),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showProfile();
                  },
                ),
                if (!_isToday)
                  ListTile(
                    leading: const Icon(Icons.today_outlined),
                    title: Text(_dayName(context, DateTime.now())),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _goToToday();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _refreshEvents() async {
    if (!mounted) return;
    await Provider.of<EventProvider>(context, listen: false).loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EventProvider>(
      builder: (context, eventProvider, child) {
        final events = eventProvider.getEventsForDay(_selectedDate).toList();
        final scheme = Theme.of(context).colorScheme;

        return Scaffold(
          backgroundColor: scheme.surface,
          appBar: M3EAppBar.top(
            backgroundColor: scheme.surface,
            elevation: 0,
            title: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _goToToday,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dayName(context, _selectedDate),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      '${_selectedDate.day.toString().padLeft(2, '0')}/'
                      '${_selectedDate.month.toString().padLeft(2, '0')}/'
                      '${_selectedDate.year}',
                      style: TextStyle(
                        fontSize: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              M3EIconButton(
                icon: const Icon(Icons.more_horiz),
                onPressed: _showMenu,
                tooltip: 'More',
              ),
            ],
          ),
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity < -250) {
                _changeDay(1);
              } else if (velocity > 250) {
                _changeDay(-1);
              }
            },
            child: M3ERefreshIndicator.contained(
              onRefresh: _refreshEvents,
              child: eventProvider.isLoading && events.isEmpty
                  ? const Center(child: M3ELoadingIndicator())
                  : DayScreen(
                      day: _selectedDate,
                      events: events,
                      onAddEvent: eventProvider.addEvent,
                      onUpdateEvent: (index, event) =>
                          eventProvider.updateEvent(event),
                      onDeleteEvent: (index, deleteAll) async {
                        if (index < 0 || index >= events.length) return;
                        await eventProvider.deleteEvent(
                          events[index].id,
                          deleteAll: deleteAll,
                        );
                      },
                    ),
            ),
          ),
        );
      },
    );
  }
}
