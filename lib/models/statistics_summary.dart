import 'package:myapp/models/daily_stats.dart';

class StatisticsSummary {
  final int totalEvents;
  final int completedEvents;
  final double completionRate;
  final Map<String, int> categoryStats;
  final Map<int, int> importanceStats;
  final Duration? averageCompletionTime;
  final List<DailyStats> dailyStats;

  StatisticsSummary({
    required this.totalEvents,
    required this.completedEvents,
    required this.completionRate,
    required this.categoryStats,
    required this.importanceStats,
    this.averageCompletionTime,
    required this.dailyStats,
  });

  factory StatisticsSummary.fromJson(Map<String, dynamic> json) {
    return StatisticsSummary(
      totalEvents: json['total_events'] ?? 0,
      completedEvents: json['completed_events'] ?? 0,
      completionRate: (json['completion_rate'] ?? 0.0).toDouble(),
      categoryStats: Map<String, int>.from(json['category_stats'] ?? {}),
      importanceStats: Map<int, int>.fromEntries(
        (json['importance_stats'] ?? {}).map(
          (k, v) => MapEntry(int.parse(k.toString()), v),
        ),
      ),
      averageCompletionTime: json['average_completion_time'] != null
          ? Duration(milliseconds: json['average_completion_time'])
          : null,
      dailyStats: (json['daily_stats'] as List? ?? [])
          .map((item) => DailyStats.fromJson(item))
          .toList(),
    );
  }
}
