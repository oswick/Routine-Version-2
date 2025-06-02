// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Event _$EventFromJson(Map<String, dynamic> json) => Event(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] == null
          ? null
          : DateTime.parse(json['end_time'] as String),
      repeatDays: (json['repeat_days'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
      importance: (json['importance'] as num?)?.toInt(),
      category: json['category'] as String,
      isCompleted: json['is_completed'] as bool? ?? false,
      userId: json['user_id'] as String,
      lastModified: json['last_modified'] == null
          ? null
          : DateTime.parse(json['last_modified'] as String),
    );

Map<String, dynamic> _$EventToJson(Event instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'start_time': instance.startTime.toIso8601String(),
      'end_time': instance.endTime?.toIso8601String(),
      'repeat_days': instance.repeatDays,
      'importance': instance.importance,
      'category': instance.category,
      'is_completed': instance.isCompleted,
      'user_id': instance.userId,
      'last_modified': instance.lastModified.toIso8601String(),
    };
