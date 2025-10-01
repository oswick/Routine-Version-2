// lib/services/local_storage_service.dart - VERSIÓN OPTIMIZADA
import 'package:hive_flutter/hive_flutter.dart';
import '../models/event.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  static const String _eventsBoxName = 'events';
  Box<Event>? _eventsBox;
  
  // 🆕 NUEVO: Cache en memoria para acceso rápido
  Map<String, Event>? _eventsCache;
  bool _cacheNeedsUpdate = true;

  Future<void> init() async {
    await Hive.initFlutter();
    
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(EventAdapter());
    }

    _eventsBox = await Hive.openBox<Event>(_eventsBoxName);
    print('📦 Local storage initialized');
    
    // 🆕 Inicializar cache
    _rebuildCache();
  }

  // 🆕 NUEVO: Reconstruir cache
  void _rebuildCache() {
    if (_eventsBox == null) return;
    
    _eventsCache = {};
    for (var event in _eventsBox!.values) {
      if (!event.isDeleted) {
        _eventsCache![event.id] = event;
      }
    }
    _cacheNeedsUpdate = false;
    print('📦 Cache rebuilt with ${_eventsCache!.length} events');
  }

  // 🆕 NUEVO: Invalidar cache
  void _invalidateCache() {
    _cacheNeedsUpdate = true;
  }

  // 🆕 OPTIMIZADO: Usar cache en lugar de iterar siempre
  List<Event> getAllEvents() {
    if (_eventsBox == null) return [];
    
    if (_cacheNeedsUpdate || _eventsCache == null) {
      _rebuildCache();
    }
    
    return _eventsCache!.values.toList();
  }

  // 🆕 OPTIMIZADO: Filtrado más eficiente
  List<Event> getUnsyncedEvents() {
    if (_eventsBox == null) return [];
    
    if (_cacheNeedsUpdate || _eventsCache == null) {
      _rebuildCache();
    }
    
    return _eventsCache!.values
        .where((event) => event.needsSync)
        .toList();
  }

  List<Event> getDeletedEvents() {
    if (_eventsBox == null) return [];
    
    // Para eventos eliminados, necesitamos buscar en el box completo
    return _eventsBox!.values
        .where((event) => event.isDeleted && event.needsSync)
        .toList();
  }

  // 🆕 OPTIMIZADO: Actualizar cache al guardar
  Future<void> saveEvent(Event event) async {
    if (_eventsBox == null) return;
    
    await _eventsBox!.put(event.id, event);
    
    // Actualizar cache
    if (_eventsCache != null && !event.isDeleted) {
      _eventsCache![event.id] = event;
    } else {
      _invalidateCache();
    }
    
    print('💾 Event saved locally: ${event.title}');
  }

  // 🆕 OPTIMIZADO: Acceso directo desde cache
  Event? getEvent(String id) {
    if (_eventsBox == null) return null;
    
    // Intentar desde cache primero
    if (_eventsCache != null && !_cacheNeedsUpdate) {
      return _eventsCache![id];
    }
    
    // Fallback a Hive
    return _eventsBox!.get(id);
  }

  // 🆕 OPTIMIZADO: Actualizar cache al eliminar
  Future<void> deleteEvent(String eventId, {bool permanent = false}) async {
    if (_eventsBox == null) return;
    
    if (permanent) {
      await _eventsBox!.delete(eventId);
      _eventsCache?.remove(eventId);
      print('🗑️ Event permanently deleted locally: $eventId');
    } else {
      final event = _eventsBox!.get(eventId);
      if (event != null) {
        final deletedEvent = event.copyWith(
          isDeleted: true,
          needsSync: true,
        );
        await _eventsBox!.put(eventId, deletedEvent);
        _eventsCache?.remove(eventId); // Remover del cache
        print('🗑️ Event marked as deleted locally: $eventId');
      }
    }
  }

  Future<void> markAsSynced(String eventId) async {
    if (_eventsBox == null) return;
    
    final event = _eventsBox!.get(eventId);
    if (event != null) {
      final syncedEvent = event.copyWith(needsSync: false);
      await _eventsBox!.put(eventId, syncedEvent);
      
      // Actualizar cache
      if (_eventsCache != null && !syncedEvent.isDeleted) {
        _eventsCache![eventId] = syncedEvent;
      }
    }
  }

  // 🆕 OPTIMIZADO: Batch operation
  Future<void> cleanupSyncedDeletedEvents() async {
    if (_eventsBox == null) return;
    
    final eventsToDelete = _eventsBox!.values
        .where((event) => event.isDeleted && !event.needsSync)
        .map((event) => event.id)
        .toList();
    
    if (eventsToDelete.isEmpty) return;
    
    // 🆕 Usar deleteAll en lugar de loop
    await _eventsBox!.deleteAll(eventsToDelete);
    
    // Invalidar cache después de limpieza
    _invalidateCache();
    
    print('🧹 Cleaned up ${eventsToDelete.length} synced deleted events');
  }

  // 🆕 OPTIMIZADO: Calcular stats desde cache
  Map<String, int> getStorageStats() {
    if (_eventsBox == null) return {};
    
    if (_cacheNeedsUpdate || _eventsCache == null) {
      _rebuildCache();
    }
    
    final allEvents = _eventsBox!.values.toList();
    
    return {
      'total': allEvents.length,
      'active': _eventsCache!.length,
      'deleted': allEvents.where((e) => e.isDeleted).length,
      'unsynced': allEvents.where((e) => e.needsSync).length,
    };
  }

  // 🆕 NUEVO: Método para limpiar eventos antiguos (más de 6 meses)
  Future<void> cleanupOldEvents({int months = 6}) async {
    if (_eventsBox == null) return;
    
    final cutoffDate = DateTime.now().subtract(Duration(days: months * 30));
    
    final oldEvents = _eventsBox!.values
        .where((event) {
          // Solo eliminar eventos únicos (no repetitivos) completados y antiguos
          return event.repeatDays.isEmpty &&
                 event.isCompleted &&
                 event.startTime.isBefore(cutoffDate);
        })
        .map((event) => event.id)
        .toList();
    
    if (oldEvents.isNotEmpty) {
      await _eventsBox!.deleteAll(oldEvents);
      _invalidateCache();
      print('🧹 Cleaned up ${oldEvents.length} old completed events');
    }
  }

  // 🆕 NUEVO: Compactar base de datos
  Future<void> compact() async {
    if (_eventsBox == null) return;
    
    try {
      await _eventsBox!.compact();
      print('📦 Database compacted successfully');
    } catch (e) {
      print('❌ Error compacting database: $e');
    }
  }

  Future<void> close() async {
    await _eventsBox?.close();
    _eventsCache?.clear();
    _eventsCache = null;
  }
}
