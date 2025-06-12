import 'package:myapp/models/daily_stats.dart';
import 'package:myapp/models/statistics_summary.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event_statistics.dart';
import '../models/event.dart';

class StatisticsService {
  static final StatisticsService _instance = StatisticsService._internal();
  factory StatisticsService() => _instance;
  StatisticsService._internal();

  final supabase = Supabase.instance.client;

  /// Records the completion status of an event
  Future<bool> recordEventCompletion(
    Event event, 
    bool wasCompleted, 
    [DateTime? completedTime]
  ) async {
    try {
      final statistics = EventStatistics.fromEvent(
        event, 
        wasCompleted,
        completedTime ?? (wasCompleted ? DateTime.now() : null)
      );

      await supabase
          .from('event_statistics')
          .upsert(statistics.toJson(), onConflict: 'event_id,user_id,date');
      
      return true;
    } catch (e) {
      print('Error recording event statistics: $e');
      return false;
    }
  }

  /// Gets comprehensive statistics for a specific date
  Future<Map<String, dynamic>> getDailyStatistics(
    String userId, 
    DateTime date
  ) async {
    try {
      final dateString = date.toIso8601String().split('T')[0];

      final response = await supabase
          .from('event_statistics')
          .select()
          .eq('user_id', userId)
          .eq('date', dateString);

      final stats = (response as List)
          .map((json) => EventStatistics.fromJson(json))
          .toList();

      return {
        'date': date,
        'total': stats.length,
        'completed': stats.where((s) => s.wasCompleted).length,
        'completion_rate': stats.isEmpty ? 0.0 : 
            stats.where((s) => s.wasCompleted).length / stats.length,
        'by_category': _getCategoryStats(stats),
        'by_importance': _getImportanceStats(stats),
        'average_completion_time': _getAverageCompletionTime(stats),
        'longest_completion_time': _getLongestCompletionTime(stats),
        'shortest_completion_time': _getShortestCompletionTime(stats),
      };
    } catch (e) {
      print('Error getting daily statistics: $e');
      return {'error': e.toString()};
    }
  }

  /// Gets statistics for a date range
  Future<StatisticsSummary> getDateRangeStatistics(
    String userId, 
    DateTime startDate, 
    DateTime endDate
  ) async {
    try {
      final startDateString = startDate.toIso8601String().split('T')[0];
      final endDateString = endDate.toIso8601String().split('T')[0];

      final response = await supabase
          .from('event_statistics')
          .select()
          .eq('user_id', userId)
          .gte('date', startDateString)
          .lte('date', endDateString)
          .order('date', ascending: true);

      final stats = (response as List)
          .map((json) => EventStatistics.fromJson(json))
          .toList();

      final completedStats = stats.where((s) => s.wasCompleted).toList();
      
      // Calculate daily statistics
      final dailyStatsMap = <String, List<EventStatistics>>{};
      for (var stat in stats) {
        final dateKey = stat.date.toIso8601String().split('T')[0];
        dailyStatsMap.putIfAbsent(dateKey, () => []).add(stat);
      }

      final dailyStats = dailyStatsMap.entries.map((entry) {
        final dayStats = entry.value;
        final completed = dayStats.where((s) => s.wasCompleted).length;
        return DailyStats(
          date: DateTime.parse(entry.key),
          totalEvents: dayStats.length,
          completedEvents: completed,
          completionRate: dayStats.isEmpty ? 0.0 : completed / dayStats.length,
        );
      }).toList();

      return StatisticsSummary(
        totalEvents: stats.length,
        completedEvents: completedStats.length,
        completionRate: stats.isEmpty ? 0.0 : completedStats.length / stats.length,
        categoryStats: _getCategoryStats(completedStats),
        importanceStats: _getImportanceStats(completedStats),
        averageCompletionTime: _getAverageCompletionTime(completedStats),
        dailyStats: dailyStats,
      );
    } catch (e) {
      print('Error getting date range statistics: $e');
      return StatisticsSummary(
        totalEvents: 0,
        completedEvents: 0,
        completionRate: 0.0,
        categoryStats: {},
        importanceStats: {},
        dailyStats: [],
      );
    }
  }

  /// Gets weekly statistics (last 7 days)
  Future<StatisticsSummary> getWeeklyStatistics(String userId) async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(days: 6));
    return getDateRangeStatistics(userId, startDate, endDate);
  }

  /// Gets monthly statistics (last 30 days)
  Future<StatisticsSummary> getMonthlyStatistics(String userId) async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(days: 29));
    return getDateRangeStatistics(userId, startDate, endDate);
  }

  /// Gets category performance over time
  Future<Map<String, List<DailyStats>>> getCategoryTrends(
    String userId,
    DateTime startDate,
    DateTime endDate
  ) async {
    try {
      final startDateString = startDate.toIso8601String().split('T')[0];
      final endDateString = endDate.toIso8601String().split('T')[0];

      final response = await supabase
          .from('event_statistics')
          .select()
          .eq('user_id', userId)
          .gte('date', startDateString)
          .lte('date', endDateString)
          .order('date', ascending: true);

      final stats = (response as List)
          .map((json) => EventStatistics.fromJson(json))
          .toList();

      final categoryTrends = <String, Map<String, List<EventStatistics>>>{};
      
      for (var stat in stats) {
        final dateKey = stat.date.toIso8601String().split('T')[0];
        categoryTrends
            .putIfAbsent(stat.category, () => {})
            .putIfAbsent(dateKey, () => [])
            .add(stat);
      }

      final result = <String, List<DailyStats>>{};
      for (var category in categoryTrends.keys) {
        final categoryData = categoryTrends[category]!;
        result[category] = categoryData.entries.map((entry) {
          final dayStats = entry.value;
          final completed = dayStats.where((s) => s.wasCompleted).length;
          return DailyStats(
            date: DateTime.parse(entry.key),
            totalEvents: dayStats.length,
            completedEvents: completed,
            completionRate: dayStats.isEmpty ? 0.0 : completed / dayStats.length,
          );
        }).toList();
      }

      return result;
    } catch (e) {
      print('Error getting category trends: $e');
      return {};
    }
  }

  /// Gets the most productive time of day based on completion rates
  Future<Map<int, double>> getProductiveHours(String userId) async {
    try {
      final response = await supabase
          .from('event_statistics')
          .select('scheduled_start_time, was_completed')
          .eq('user_id', userId)
          .eq('was_completed', true);

      final stats = (response as List)
          .map((json) => EventStatistics.fromJson(json))
          .toList();

      final hourlyStats = <int, List<bool>>{};
      
      for (var stat in stats) {
        final hour = stat.scheduledStartTime.hour;
        hourlyStats.putIfAbsent(hour, () => []).add(stat.wasCompleted);
      }

      final productiveHours = <int, double>{};
      for (var hour in hourlyStats.keys) {
        final completions = hourlyStats[hour]!;
        final completionRate = completions.where((c) => c).length / completions.length;
        productiveHours[hour] = completionRate;
      }

      return productiveHours;
    } catch (e) {
      print('Error getting productive hours: $e');
      return {};
    }
  }

  /// Helper method to get category statistics
  Map<String, int> _getCategoryStats(List<EventStatistics> stats) {
    final categoryStats = <String, int>{};
    for (var stat in stats) {
      categoryStats[stat.category] = (categoryStats[stat.category] ?? 0) + 1;
    }
    return categoryStats;
  }

  /// Helper method to get importance statistics
  Map<int, int> _getImportanceStats(List<EventStatistics> stats) {
    final importanceStats = <int, int>{};
    for (var stat in stats.where((s) => s.importance != null)) {
      final importance = stat.importance!;
      importanceStats[importance] = (importanceStats[importance] ?? 0) + 1;
    }
    return importanceStats;
  }

  /// Helper method to calculate average completion time
  Duration? _getAverageCompletionTime(List<EventStatistics> stats) {
    final validStats = stats.where((s) => 
        s.wasCompleted && s.completionDuration != null).toList();
    
    if (validStats.isEmpty) return null;

    final totalDuration = validStats.fold<Duration>(
      Duration.zero,
      (total, stat) => total + stat.completionDuration!
    );

    return Duration(
      milliseconds: totalDuration.inMilliseconds ~/ validStats.length
    );
  }

  /// Helper method to get longest completion time
  Duration? _getLongestCompletionTime(List<EventStatistics> stats) {
    final validStats = stats.where((s) => 
        s.wasCompleted && s.completionDuration != null).toList();
    
    if (validStats.isEmpty) return null;

    return validStats.map((s) => s.completionDuration!).reduce(
      (a, b) => a.compareTo(b) > 0 ? a : b
    );
  }

  /// Helper method to get shortest completion time
  Duration? _getShortestCompletionTime(List<EventStatistics> stats) {
    final validStats = stats.where((s) => 
        s.wasCompleted && s.completionDuration != null).toList();
    
    if (validStats.isEmpty) return null;

    return validStats.map((s) => s.completionDuration!).reduce(
      (a, b) => a.compareTo(b) < 0 ? a : b
    );
  }

  /// Delete old statistics (for cleanup)
  Future<bool> deleteOldStatistics(String userId, DateTime beforeDate) async {
    try {
      final dateString = beforeDate.toIso8601String().split('T')[0];
      
      await supabase
          .from('event_statistics')
          .delete()
          .eq('user_id', userId)
          .lt('date', dateString);
      
      return true;
    } catch (e) {
      print('Error deleting old statistics: $e');
      return false;
    }
  }

  /// Export statistics to JSON
  Future<Map<String, dynamic>?> exportStatistics(
    String userId,
    DateTime startDate,
    DateTime endDate
  ) async {
    try {
      final summary = await getDateRangeStatistics(userId, startDate, endDate);
      final categoryTrends = await getCategoryTrends(userId, startDate, endDate);
      final productiveHours = await getProductiveHours(userId);

      return {
        'export_date': DateTime.now().toIso8601String(),
        'date_range': {
          'start': startDate.toIso8601String(),
          'end': endDate.toIso8601String(),
        },
        'summary': {
          'total_events': summary.totalEvents,
          'completed_events': summary.completedEvents,
          'completion_rate': summary.completionRate,
          'category_stats': summary.categoryStats,
          'importance_stats': summary.importanceStats,
          'average_completion_time_ms': summary.averageCompletionTime?.inMilliseconds,
        },
        'daily_stats': summary.dailyStats.map((d) => {
          'date': d.date.toIso8601String().split('T')[0],
          'total_events': d.totalEvents,
          'completed_events': d.completedEvents,
          'completion_rate': d.completionRate,
        }).toList(),
        'category_trends': categoryTrends,
        'productive_hours': productiveHours,
      };
    } catch (e) {
      print('Error exporting statistics: $e');
      return null;
    }
  }
}