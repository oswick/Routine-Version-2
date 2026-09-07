import 'package:hive/hive.dart';

import 'focus_phase.dart';

@HiveType(typeId: 1)
class FocusSession extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String? eventId;

  @HiveField(2)
  final DateTime startedAt;

  @HiveField(3)
  final DateTime? endedAt;

  @HiveField(4)
  final Duration duration;

  @HiveField(5)
  final FocusPhase type;

  @HiveField(6)
  final bool completed;

  @HiveField(7)
  final bool interrupted;

  FocusSession({
    required this.id,
    this.eventId,
    required this.startedAt,
    this.endedAt,
    required this.duration,
    required this.type,
    this.completed = false,
    this.interrupted = false,
  });

  FocusSession copyWith({
    String? id,
    String? eventId,
    bool clearEventId = false,
    DateTime? startedAt,
    DateTime? endedAt,
    bool clearEndedAt = false,
    Duration? duration,
    FocusPhase? type,
    bool? completed,
    bool? interrupted,
  }) {
    return FocusSession(
      id: id ?? this.id,
      eventId: clearEventId ? null : eventId ?? this.eventId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: clearEndedAt ? null : endedAt ?? this.endedAt,
      duration: duration ?? this.duration,
      type: type ?? this.type,
      completed: completed ?? this.completed,
      interrupted: interrupted ?? this.interrupted,
    );
  }
}

class FocusSessionAdapter extends TypeAdapter<FocusSession> {
  @override
  final int typeId = 1;

  @override
  FocusSession read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < fieldCount; i++)
        reader.readByte(): reader.read(),
    };

    final rawType = fields[5] as String? ?? FocusPhase.focus.storageValue;

    return FocusSession(
      id: fields[0] as String,
      eventId: fields[1] as String?,
      startedAt: fields[2] as DateTime,
      endedAt: fields[3] as DateTime?,
      duration: Duration(microseconds: fields[4] as int),
      type: FocusPhaseX.fromStorageValue(rawType),
      completed: fields[6] as bool? ?? false,
      interrupted: fields[7] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, FocusSession obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.eventId)
      ..writeByte(2)
      ..write(obj.startedAt)
      ..writeByte(3)
      ..write(obj.endedAt)
      ..writeByte(4)
      ..write(obj.duration.inMicroseconds)
      ..writeByte(5)
      ..write(obj.type.storageValue)
      ..writeByte(6)
      ..write(obj.completed)
      ..writeByte(7)
      ..write(obj.interrupted);
  }
}
