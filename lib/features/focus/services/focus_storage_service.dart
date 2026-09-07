import 'package:hive_flutter/hive_flutter.dart';

import '../models/focus_session.dart';

class FocusStorageService {
  static final FocusStorageService _instance = FocusStorageService._internal();
  factory FocusStorageService() => _instance;
  FocusStorageService._internal();

  static const String _boxName = 'focus_sessions';
  Box<FocusSession>? _box;

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(FocusSessionAdapter());
    }
    _box = await Hive.openBox<FocusSession>(_boxName);
  }

  Future<void> save(FocusSession session) async {
    await _requireBox().put(session.id, session);
  }

  Future<void> delete(String id) async {
    await _requireBox().delete(id);
  }

  FocusSession? get(String id) => _requireBox().get(id);

  List<FocusSession> getAll() {
    final sessions = _requireBox().values.toList();
    sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return sessions;
  }

  List<FocusSession> getForEvent(String eventId) => getAll()
      .where((session) => session.eventId == eventId)
      .toList();

  List<FocusSession> getForDay(DateTime day) {
    return getAll().where((session) {
      final date = session.startedAt;
      return date.year == day.year &&
          date.month == day.month &&
          date.day == day.day;
    }).toList();
  }

  Box<FocusSession> _requireBox() {
    final box = _box;
    if (box == null || !box.isOpen) {
      throw StateError('FocusStorageService has not been initialized.');
    }
    return box;
  }

  Future<void> close() async {
    await _box?.close();
    _box = null;
  }
}
