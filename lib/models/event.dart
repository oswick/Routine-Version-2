class Event {
  final String id;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime? endTime;
  final List<int> repeatDays; // List of days of the week (1 = Monday, 7 = Sunday)
  final int? importance; // 0: None, 1: Low, 2: Moderate, 3: Important, 4: Very Important
  final String category; // New field for category
  bool isCompleted; // Field to indicate if the event is completed

  Event({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    this.endTime,
    required this.repeatDays,
    this.importance,
    required this.category, // New field for category
    this.isCompleted = false, // Default value
  });

  // Convert Event to JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'repeatDays': repeatDays,
    'importance': importance,
    'category': category, // New field for category
    'isCompleted': isCompleted,
  };

  // Create Event from JSON
  factory Event.fromJson(Map<String, dynamic> json) => Event(
    id: json['id'],
    title: json['title'],
    description: json['description'],
    startTime: DateTime.parse(json['startTime']),
    endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
    repeatDays: List<int>.from(json['repeatDays']),
    importance: json['importance'],
    category: json['category'], // New field for category
    isCompleted: json['isCompleted'] ?? false,
  );

  // Create a copy of the Event with optional field updates
  Event copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    List<int>? repeatDays,
    int? importance,
    String? category, // New field for category
    bool? isCompleted,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      repeatDays: repeatDays ?? this.repeatDays,
      importance: importance ?? this.importance,
      category: category ?? this.category, // New field for category
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
