import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myapp/models/statistics_summary.dart' show StatisticsSummary;
import '../services/sync_service.dart';
import '../services/auth_service.dart';
import '../models/event.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  _StatisticsScreenState createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final SyncService _syncService = SyncService();
  final AuthService _authService = AuthService();
  Map<String, dynamic> _dailyStats = {};
  StatisticsSummary _summaryStats = StatisticsSummary(
    totalEvents: 0,
    completedEvents: 0,
    completionRate: 0.0,
    categoryStats: {},
    importanceStats: {},
    dailyStats: [],
  );
  DateTime _selectedDate = DateTime.now();
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  bool _isLoading = true;
  String _viewMode = 'daily'; // 'daily' or 'summary'
  List<Event> _pastEvents = [];

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);

    try {
      final userId = _authService.currentUserId;
      if (userId == null) return;

      // Cargar estadísticas
      if (_viewMode == 'daily') {
        final stats = await _syncService.generateDailyStatistics(userId, _selectedDate);
        setState(() {
          _dailyStats = stats;
        });
      } else {
        final stats = await _syncService.generateStatisticsSummary(
          userId,
          _dateRange.start,
          _dateRange.end,
        );
        setState(() {
          _summaryStats = stats;
        });
      }

      // Cargar eventos pasados
      DateTime startDate, endDate;
      if (_viewMode == 'daily') {
        startDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        endDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);
      } else {
        startDate = _dateRange.start;
        endDate = _dateRange.end;
      }

      // Obtener eventos pasados (que ya ocurrieron)
      final allEvents = await _syncService.getEvents();
      final now = DateTime.now();
      final pastEvents = allEvents.where((event) {
        final eventDate = DateTime(event.startTime.year, event.startTime.month, event.startTime.day);
        final eventEndTime = event.endTime ?? event.startTime;

        // El evento es pasado si sucede antes de ahora y está dentro del rango de fechas seleccionado
        return eventEndTime.isBefore(now) &&
               eventDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
               eventDate.isBefore(endDate.add(const Duration(days: 1)));
      }).toList();

      setState(() {
        _pastEvents = pastEvents;
        _isLoading = false;
      });

    } catch (e) {
      print('Error loading statistics: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      await _loadStatistics();
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _dateRange) {
      setState(() => _dateRange = picked);
      await _loadStatistics();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        title: Text(
          _viewMode == 'daily' ? 'Daily Statistics' : 'Summary Statistics',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurface),
            onSelected: (value) {
              setState(() => _viewMode = value);
              _loadStatistics();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'daily', child: Text('Daily View')),
              const PopupMenuItem(value: 'summary', child: Text('Summary View')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        if (_viewMode == 'daily') _buildDailyView(),
                        if (_viewMode == 'summary') _buildSummaryView(),
                      ],
                    ),
                  ),
                ),
                // Sección de eventos pasados
                if (!_isLoading)
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: _buildPastEventsView(),
                  ),
              ],
            ),
    );
  }

  Widget _buildDailyView() {
    final completionRate = (_dailyStats['completion_rate'] ?? 0.0) * 100;
    final totalEvents = _dailyStats['total_events'] ?? 0;
    final completedEvents = _dailyStats['completed_events'] ?? 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Statistics for ${DateFormat('MMMM d, yyyy').format(_selectedDate)}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.onSurface),
                onPressed: () => _selectDate(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildCompletionRateCard(completionRate, totalEvents, completedEvents),
          const SizedBox(height: 24),
          _buildCategoryStatsCard(_dailyStats['by_category'] ?? {}),
          const SizedBox(height: 24),
          _buildImportanceStatsCard(_dailyStats['by_importance'] ?? {}),
          const SizedBox(height: 24),
          Divider(color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 8),
          Text(
            'Past Events',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSummaryView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Summary Statistics',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                '${DateFormat('MMM d, yyyy').format(_dateRange.start)} to ${DateFormat('MMM d, yyyy').format(_dateRange.end)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _dateRange = DateTimeRange(
                          start: DateTime.now().subtract(const Duration(days: 7)),
                          end: DateTime.now(),
                        );
                      });
                      _loadStatistics();
                    },
                    child: Text(
                      'Last 7 Days',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _dateRange = DateTimeRange(
                          start: DateTime.now().subtract(const Duration(days: 30)),
                          end: DateTime.now(),
                        );
                      });
                      _loadStatistics();
                    },
                    child: Text(
                      'Last 30 Days',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.onSurface),
                    onPressed: () => _selectDateRange(context),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildCompletionRateCard(
            (_summaryStats.completionRate * 100).roundToDouble(),
            _summaryStats.totalEvents,
            _summaryStats.completedEvents,
          ),
          const SizedBox(height: 24),
          _buildCategoryStatsCard(_summaryStats.categoryStats),
          const SizedBox(height: 24),
          _buildImportanceStatsCard(_summaryStats.importanceStats),
          const SizedBox(height: 24),
          _buildDailyStatsChart(),
          const SizedBox(height: 24),
          Divider(color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 8),
          Text(
            'Past Events',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCompletionRateCard(double completionRate, int totalEvents, int completedEvents) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Completion Rate',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: completionRate / 100,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      completionRate > 70 ? Colors.green :
                      completionRate > 30 ? Colors.orange : Colors.red,
                    ),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${completionRate.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$completedEvents completed',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                Text(
                  '$totalEvents total',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryStatsCard(Map<String, int> categoryStats) {
    if (categoryStats.isEmpty) {
      return Card(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No category data available',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      );
    }

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Categories',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ...categoryStats.entries.map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        '${entry.value} events',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildImportanceStatsCard(Map<int, int> importanceStats) {
    if (importanceStats.isEmpty) {
      return Card(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No priority data available',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      );
    }

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'By Priority',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ...importanceStats.entries.map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _getImportanceText(entry.key),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        '${entry.value} events',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyStatsChart() {
    final dailyStats = _summaryStats.dailyStats;

    if (dailyStats.isEmpty) {
      return Card(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No daily statistics available',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      );
    }

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Completion Rate',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ...dailyStats.map((stat) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          DateFormat('MMM dd').format(stat.date),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: stat.completionRate,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            stat.completionRate > 0.7 ? Colors.green :
                            stat.completionRate > 0.3 ? Colors.orange : Colors.red,
                          ),
                          minHeight: 10,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(stat.completionRate * 100).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildPastEventsView() {
    if (_pastEvents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No past events found',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            _viewMode == 'daily'
                ? 'Past Events on ${DateFormat('MMMM d, yyyy').format(_selectedDate)}'
                : 'Past Events from ${DateFormat('MMM d, yyyy').format(_dateRange.start)} to ${DateFormat('MMM d, yyyy').format(_dateRange.end)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _pastEvents.length,
            itemBuilder: (context, index) {
              final event = _pastEvents[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event.title,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (event.isCompleted)
                            Icon(Icons.check_circle, color: Colors.green)
                          else
                            Icon(Icons.radio_button_unchecked, color: Theme.of(context).colorScheme.outline),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                          const SizedBox(width: 4),
                          Text(
                            '${DateFormat('MMM d, yyyy h:mm a').format(event.startTime)} - ${event.endTime != null ? DateFormat('h:mm a').format(event.endTime!) : 'No end time'}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                      if (event.repeatDays.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.repeat, size: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                            const SizedBox(width: 4),
                            Text(
                              'Repeats on ${_getRepeatDaysText(event.repeatDays)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      if (event.description != null && event.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            event.description!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _getImportanceText(int importance) {
    switch (importance) {
      case 1: return 'Low';
      case 2: return 'Medium-Low';
      case 3: return 'Medium';
      case 4: return 'Medium-High';
      case 5: return 'High';
      default: return 'Unknown';
    }
  }

  String _getRepeatDaysText(List<int> repeatDays) {
    final days = <String>[];
    for (var day in repeatDays) {
      switch (day) {
        case 1: days.add('Mon'); break;
        case 2: days.add('Tue'); break;
        case 3: days.add('Wed'); break;
        case 4: days.add('Thu'); break;
        case 5: days.add('Fri'); break;
        case 6: days.add('Sat'); break;
        case 7: days.add('Sun'); break;
      }
    }
    return days.join(', ');
  }
}
