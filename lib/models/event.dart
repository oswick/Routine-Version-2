import 'package:json_annotation/json_annotation.dart';
import 'package:hive/hive.dart';
part 'event.g.dart';

@JsonSerializable()
@HiveType(typeId: 0)
class Event extends HiveObject {
  @HiveField(0)
  final String id;
    
  @HiveField(1)
  final String title;
    
  @HiveField(2)
  final String? description;
    
  @JsonKey(name: 'start_time')
  @HiveField(3)
  final DateTime startTime;
    
  @JsonKey(name: 'end_time')
  @HiveField(4)
  final DateTime? endTime;
    
  @JsonKey(name: 'repeat_days')
  @HiveField(5)
  final List<int> repeatDays;
    
  @HiveField(6)
  final int? importance;
    
  @HiveField(7)
  final String category;
    
  @JsonKey(name: 'is_completed')
  @HiveField(8)
  bool isCompleted;
    
  @JsonKey(name: 'user_id')
  @HiveField(9)
  final String userId;
    
  @JsonKey(name: 'last_modified')
  @HiveField(10)
  DateTime lastModified;
    
  // Campos para manejo offline - NO incluir en JSON de Supabase
  @JsonKey(includeFromJson: false, includeToJson: false)
  @HiveField(11)
  bool needsSync;
    
  @JsonKey(includeFromJson: false, includeToJson: false)
  @HiveField(12)
  bool isDeleted;

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
    this.needsSync = false,
    this.isDeleted = false,
  }) : lastModified = lastModified ?? DateTime.now();

  factory Event.fromJson(Map<String, dynamic> json) {
    final event = _$EventFromJson(json);
    // Al venir del servidor, no necesita sincronización
    event.needsSync = false;
    event.isDeleted = false;
    return event;
  }

  Map<String, dynamic> toJson() {
    final json = _$EventToJson(this);
    
    // Asegurar que las fechas estén en formato ISO correcto
    json['start_time'] = startTime.toIso8601String();
    if (endTime != null) {
      json['end_time'] = endTime!.toIso8601String();
    }
    json['last_modified'] = lastModified.toIso8601String();
    
    // Asegurar que repeat_days sea una lista de enteros
    json['repeat_days'] = repeatDays.map((day) => day.toInt()).toList();
    
    return json;
  }

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
    bool? needsSync,
    bool? isDeleted,
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
      lastModified: lastModified ?? (needsSync == true ? DateTime.now() : this.lastModified),
      needsSync: needsSync ?? (lastModified != null ? true : this.needsSync),
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  String toString() {
    return 'Event(id: $id, title: $title, needsSync: $needsSync, isDeleted: $isDeleted)';
  }
}