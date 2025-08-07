import 'package:hive_flutter/hive_flutter.dart';
import '../models/event.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  static const String _eventsBoxName = 'events';
  Box<Event>? _eventsBox;

  Future<void> init() async {
    await Hive.initFlutter();
    
    // Registrar el adaptador de Event
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(EventAdapter());
    }

    // Abrir la caja de eventos
    _eventsBox = await Hive.openBox<Event>(_eventsBoxName);
    print('📦 Local storage initialized');
  }

  // Obtener todos los eventos locales (no eliminados)
  List<Event> getAllEvents() {
    if (_eventsBox == null) return [];
    
    return _eventsBox!.values
        .where((event) => !event.isDeleted)
        .toList();
  }

  // Obtener eventos que necesitan sincronización
  List<Event> getUnsyncedEvents() {
    if (_eventsBox == null) return [];
    
    return _eventsBox!.values
        .where((event) => event.needsSync)
        .toList();
  }

  // Obtener eventos eliminados que necesitan sincronización
  List<Event> getDeletedEvents() {
    if (_eventsBox == null) return [];
    
    return _eventsBox!.values
        .where((event) => event.isDeleted && event.needsSync)
        .toList();
  }

  // Guardar evento localmente
  Future<void> saveEvent(Event event) async {
    if (_eventsBox == null) return;
    
    await _eventsBox!.put(event.id, event);
    print('💾 Event saved locally: ${event.title}');
  }

  // Obtener evento por ID
  Event? getEvent(String id) {
    if (_eventsBox == null) return null;
    return _eventsBox!.get(id);
  }

  // Eliminar evento localmente (marca como eliminado)
  Future<void> deleteEvent(String eventId, {bool permanent = false}) async {
    if (_eventsBox == null) return;
    
    if (permanent) {
      await _eventsBox!.delete(eventId);
      print('🗑️ Event permanently deleted locally: $eventId');
    } else {
      final event = _eventsBox!.get(eventId);
      if (event != null) {
        final deletedEvent = event.copyWith(
          isDeleted: true,
          needsSync: true,
        );
        await _eventsBox!.put(eventId, deletedEvent);
        print('🗑️ Event marked as deleted locally: $eventId');
      }
    }
  }

  // Marcar evento como sincronizado
  Future<void> markAsSynced(String eventId) async {
    if (_eventsBox == null) return;
    
    final event = _eventsBox!.get(eventId);
    if (event != null) {
      final syncedEvent = event.copyWith(needsSync: false);
      await _eventsBox!.put(eventId, syncedEvent);
    }
  }

  // Limpiar eventos eliminados y sincronizados
  Future<void> cleanupSyncedDeletedEvents() async {
    if (_eventsBox == null) return;
    
    final eventsToDelete = _eventsBox!.values
        .where((event) => event.isDeleted && !event.needsSync)
        .map((event) => event.id)
        .toList();
    
    for (String id in eventsToDelete) {
      await _eventsBox!.delete(id);
    }
    
    print('🧹 Cleaned up ${eventsToDelete.length} synced deleted events');
  }

  // Obtener estadísticas de almacenamiento local
  Map<String, int> getStorageStats() {
    if (_eventsBox == null) return {};
    
    final allEvents = _eventsBox!.values.toList();
    
    return {
      'total': allEvents.length,
      'active': allEvents.where((e) => !e.isDeleted).length,
      'deleted': allEvents.where((e) => e.isDeleted).length,
      'unsynced': allEvents.where((e) => e.needsSync).length,
    };
  }

  // Cerrar la base de datos
  Future<void> close() async {
    await _eventsBox?.close();
  }
}