// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EventAdapter extends TypeAdapter<Event> {
  @override
  final int typeId = 0;

  @override
  Event read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Event(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String?,
      startTime: fields[3] as DateTime,
      endTime: fields[4] as DateTime?,
      repeatDays: (fields[5] as List).cast<int>(),
      importance: fields[6] as int?,
      category: fields[7] as String,
      isCompleted: fields[8] as bool,
      userId: fields[9] as String,
      lastModified: fields[10] as DateTime?,
      needsSync: fields[11] as bool,
      isDeleted: fields[12] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Event obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.startTime)
      ..writeByte(4)
      ..write(obj.endTime)
      ..writeByte(5)
      ..write(obj.repeatDays)
      ..writeByte(6)
      ..write(obj.importance)
      ..writeByte(7)
      ..write(obj.category)
      ..writeByte(8)
      ..write(obj.isCompleted)
      ..writeByte(9)
      ..write(obj.userId)
      ..writeByte(10)
      ..write(obj.lastModified)
      ..writeByte(11)
      ..write(obj.needsSync)
      ..writeByte(12)
      ..write(obj.isDeleted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

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
