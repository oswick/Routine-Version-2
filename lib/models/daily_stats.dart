class DailyStats {
  final DateTime date;
  final int totalEvents;
  final int completedEvents;
  final double completionRate;

  DailyStats({
    required this.date,
    required this.totalEvents,
    required this.completedEvents,
    required this.completionRate,
  });

  factory DailyStats.fromJson(Map<String, dynamic> json) {
    return DailyStats(
      date: DateTime.parse(json['date']),
      totalEvents: json['total_events'] ?? 0,
      completedEvents: json['completed_events'] ?? 0,
      completionRate: (json['completion_rate'] ?? 0.0).toDouble(),
    );
  }
}