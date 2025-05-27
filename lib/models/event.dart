import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'event.g.dart';

@HiveType(typeId: 0)
@JsonSerializable()
class Event extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String? description;

  @HiveField(3)
  final DateTime startTime;

  @HiveField(4)
  final DateTime? endTime;

  @HiveField(5)
  final List<int> repeatDays;

  @HiveField(6)
  final int? importance;

  @HiveField(7)
  final String category;

  @HiveField(8)
  bool isCompleted;

  @HiveField(9)
  final String userId; // New field to associate with Supabase user

  @HiveField(10)
  DateTime lastModified; // For sync purposes

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

  // Factory constructor for JSON serialization
  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);
  
  // Convert to JSON
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