import 'package:json_annotation/json_annotation.dart';

part 'event.g.dart';

@JsonSerializable()
class Event {
  final String id;
  final String title;
  final String? description;
  
  @JsonKey(name: 'start_time')
  final DateTime startTime;
  
  @JsonKey(name: 'end_time')
  final DateTime? endTime;
  
  @JsonKey(name: 'repeat_days')
  final List<int> repeatDays;
  
  final int? importance;
  final String category;
  
  @JsonKey(name: 'is_completed')
  bool isCompleted;
  
  @JsonKey(name: 'user_id')
  final String userId;
  
  @JsonKey(name: 'last_modified')
  DateTime lastModified;

  Event({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    this.endTime,
    required this.repeatDays,
    this.importance,
    required this.category,
    this.isCompleted = false,
    required this.userId,
    DateTime? lastModified,
  }) : lastModified = lastModified ?? DateTime.now();

  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);
  
  Map<String, dynamic> toJson() => _$EventToJson(this);

  Event copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    List<int>? repeatDays,
    int? importance,
    String? category,
    bool? isCompleted,
    String? userId,
    DateTime? lastModified,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      repeatDays: repeatDays ?? this.repeatDays,
      importance: importance ?? this.importance,
      category: category ?? this.category,
      isCompleted: isCompleted ?? this.isCompleted,
      userId: userId ?? this.userId,
      lastModified: lastModified ?? DateTime.now(),
    );
  }
}