import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/event.dart';
import 'package:myapp/providers/event_provider.dart';
import 'package:myapp/screens/add_event_screen.dart';
import 'package:myapp/screens/calendar_screen.dart';
import 'package:myapp/screens/profile_screen.dart';
import 'package:myapp/utils/event_sorting_utils.dart';
import 'package:myapp/widgets/brutalist_event_tile.dart';
import 'package:provider/provider.dart';

/// Primary Routine experience.
///
/// Deliberately flat and typographic: the dynamic Material 3 color scheme is
/// untouched; the brutalist character comes from hard edges, borders,
/// oversized type, strict spacing and restrained motion.
class MinimalRoutineScreen extends StatefulWidget {
  const MinimalRoutineScreen({super.key});

  @override
  State<MinimalRoutineScreen> createState() => _MinimalRoutineScreenState();
}

class _MinimalRoutineScreenState extends State<MinimalRoutineScreen>
    with SingleTickerProviderStateMixin {
  DateTime _selectedDate = DateTime.now();
  Timer? _clockTimer;
  final Map<TimePeriod, bool> _expanded = {
    TimePeriod.morning: true,
    TimePeriod.afternoon: true,
    TimePeriod.evening: true,
    TimePeriod.night: true,
  };

  DateTime get _dayOnly => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );

  bool get _isToday {
    final now = DateTime.now();
    return _dayOnly == DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && _isToday) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
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

  String _periodName(BuildContext context, TimePeriod period) {
    final l10n = AppLocalizations.of(context);
    switch (period) {
      case TimePeriod.morning:
        return l10n.morning;
      case TimePeriod.afternoon:
        return l10n.afternoon;
      case TimePeriod.evening:
        return l10n.night;
      case TimePeriod.night:
        return l10n.earlyMorning;
    }
  }

  IconData _periodIcon(TimePeriod period) {
    switch (period) {
      case TimePeriod.morning:
        return Icons.wb_sunny_outlined;
      case TimePeriod.afternoon:
        return Icons.wb_twilight_outlined;
      case TimePeriod.evening:
        return Icons.nightlight_outlined;
      case TimePeriod.night:
        return Icons.dark_mode_outlined;
    }
  }

  void _changeDay(int amount) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedDate = _dayOnly.add(Duration(days: amount));
    });
  }

  void _goToToday() {
    HapticFeedback.lightImpact();
    setState(() => _selectedDate = DateTime.now());
  }

  Future<void> _showAddEvent() async {
    HapticFeedback.mediumImpact();
    final provider = context.read<EventProvider>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEventBottomSheet(
        day: _selectedDate,
        onAddEvent: provider.addEvent,
      ),
    );
  }

  Future<void> _refreshEvents() async {
    HapticFeedback.lightImpact();
    await context.read<EventProvider>().loadEvents();
  }

  Future<void> _showCalendar() async {
    HapticFeedback.selectionClick();
    final provider = context.read<EventProvider>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        height: MediaQuery.sizeOf(sheetContext).height * .94,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Theme.of(sheetContext).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border.all(color: Theme.of(sheetContext).colorScheme.outlineVariant),
        ),
        child: MonthlyCalendarScreen(
          fromHomeScreen: true,
          events: provider.events,
          onAddEvent: provider.addEvent,
          onUpdateEvent: (_, event) => provider.updateEvent(event),
          onDeleteEvent: (index, deleteAll) async {
            if (index >= 0 && index < provider.events.length) {
              await provider.deleteEvent(provider.events[index].id, deleteAll: deleteAll);
            }
          },
        ),
      ),
    );
  }

  Future<void> _showProfile() async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        height: MediaQuery.sizeOf(sheetContext).height * .94,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Theme.of(sheetContext).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border.all(color: Theme.of(sheetContext).colorScheme.outlineVariant),
        ),
        child: const ProfileScreen(),
      ),
    );
  }

  void _showMenu() {
    HapticFeedback.selectionClick();
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border.all(color: scheme.outline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _menuItem(
                context: sheetContext,
                icon: Icons.calendar_month_outlined,
                label: l10n.calendar,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showCalendar();
                },
              ),
              _menuItem(
                context: sheetContext,
                icon: Icons.person_outline,
                label: l10n.profile,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showProfile();
                },
              ),
              if (!_isToday)
                _menuItem(
                  context: sheetContext,
                  icon: Icons.today_outlined,
                  label: _dayName(context, DateTime.now()),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _goToToday();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        child: Row(
          children: [
            Icon(icon, color: scheme.onSurface, size: 22),
            const SizedBox(width: 18),
            Text(
              label,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: scheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EventProvider>(
      builder: (context, provider, _) {
        final scheme = Theme.of(context).colorScheme;
        final sorted = EventSortingUtils.sortEvents(
          provider.getEventsForDay(_selectedDate).toList(),
          _selectedDate,
          sortBy: EventSortOption.timeAscending,
        );
        final groups = EventSortingUtils.groupByTimePeriod(
          sorted,
          _selectedDate,
          sortGroups: false,
        );
        final visibleGroups = groups.entries.where((e) => e.value.isNotEmpty).toList();

        return Scaffold(
          backgroundColor: scheme.surface,
          floatingActionButton: _buildAddButton(scheme),
          body: SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity < -260) _changeDay(1);
                if (velocity > 260) _changeDay(-1);
              },
              child: RefreshIndicator(
                color: scheme.primary,
                backgroundColor: scheme.surface,
                onRefresh: _refreshEvents,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeader(scheme)),
                    if (provider.isLoading && sorted.isEmpty)
                      const SliverFillRemaining(hasScrollBody: false, child: Center(child: M3ELoadingIndicator()))
                    else if (sorted.isEmpty)
                      SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState(scheme))
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final entry = visibleGroups[index];
                              return _buildPeriod(entry.key, entry.value, scheme);
                            },
                            childCount: visibleGroups.length,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(ColorScheme scheme) {
    final day = _dayName(context, _selectedDate);
    final date = '${_selectedDate.day.toString().padLeft(2, '0')}/'
        '${_selectedDate.month.toString().padLeft(2, '0')}/'
        '${_selectedDate.year}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 28, 14, 6),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _isToday ? null : _goToToday,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: Column(
                      key: ValueKey(_dayOnly),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          day,
                          style: TextStyle(
                            fontSize: 34,
                            height: .95,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.5,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          date,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              M3EIconButton(
                icon: const Icon(Icons.more_horiz),
                onPressed: _showMenu,
                tooltip: 'More',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _navButton(Icons.chevron_left, () => _changeDay(-1), scheme),
              const SizedBox(width: 6),
              Expanded(
                child: GestureDetector(
                  onTap: _goToToday,
                  child: Container(
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Text(
                      _isToday ? 'TODAY' : 'GO TO TODAY',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: scheme.primary),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _navButton(Icons.chevron_right, () => _changeDay(1), scheme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navButton(IconData icon, VoidCallback onPressed, ColorScheme scheme) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        width: 44,
        height: 38,
        decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant)),
        child: Icon(icon, size: 21),
      ),
    );
  }

  Widget _buildPeriod(TimePeriod period, List<Event> events, ColorScheme scheme) {
    final expanded = _expanded[period] ?? true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _expanded[period] = !expanded);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(_periodIcon(period), size: 20, color: scheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    _periodName(context, period).toUpperCase(),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: scheme.onSurface),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    '${events.length}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: scheme.primary),
                  ),
                  const Spacer(),
                  Icon(expanded ? Icons.remove : Icons.add, size: 18, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Column(
              children: [
                Container(height: 1, color: scheme.outlineVariant),
                const SizedBox(height: 7),
                ...events.map((event) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: BrutalistEventTile(
                        key: ValueKey('${event.id}-${_dayOnly.millisecondsSinceEpoch}'),
                        event: event,
                        pastEvent: _isPast(event),
                      ),
                    )),
              ],
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  bool _isPast(Event event) {
    final day = _dayOnly;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (event.repeatDays.isNotEmpty) {
      if (day.isBefore(today)) return true;
      if (!_isToday) return false;
      final end = event.endTime;
      final start = DateTime(now.year, now.month, now.day, event.startTime.hour, event.startTime.minute);
      final endDate = end == null
          ? start.add(const Duration(hours: 1))
          : DateTime(now.year, now.month, now.day, end.hour, end.minute);
      return now.isAfter(endDate);
    }
    if (day.isBefore(today)) return true;
    if (!_isToday) return false;
    final end = event.endTime ?? event.startTime.add(const Duration(hours: 1));
    return now.isAfter(end);
  }

  Widget _buildEmptyState(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '—',
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: scheme.primary),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).noEventsForThisDay,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: scheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).tapPlusButtonToAddEvent,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(ColorScheme scheme) {
    return GestureDetector(
      onTapDown: (_) => HapticFeedback.selectionClick(),
      onTap: _showAddEvent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: scheme.primary,
          border: Border.all(color: scheme.onPrimary, width: 2),
          boxShadow: [BoxShadow(color: scheme.shadow.withOpacity(.16), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Icon(Icons.add, size: 30, color: scheme.onPrimary),
      ),
    );
  }
}
