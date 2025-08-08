import 'dart:async';
import 'package:myapp/services/local_stogare_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event.dart';
import 'connectivity_service.dart';
import 'auth_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final supabase = Supabase.instance.client;
  final LocalStorageService _localStorage = LocalStorageService();
  final ConnectivityService _connectivity = ConnectivityService();
  final AuthService _authService = AuthService();
  
  Timer? _syncTimer;
  bool _isSyncing = false;
  
  final StreamController<SyncStatus> _syncStatusController = 
      StreamController<SyncStatus>.broadcast();
  
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  Future<void> init() async {
    await _localStorage.init();
    await _connectivity.initialize();
    
    // Escuchar cambios de conectividad
    _connectivity.connectionStream.listen((isConnected) {
      if (isConnected) {
        print('🌐 Connection restored - starting sync');
        _startAutoSync();
      } else {
        print('📴 Connection lost - stopping sync');
        _stopAutoSync();
        _syncStatusController.add(SyncStatus.offline);
      }
    });
    
    // Si hay conexión, iniciar sincronización automática
    if (_connectivity.isConnected) {
      _startAutoSync();
    }
  }

  void _startAutoSync() {
    _stopAutoSync(); // Detener timer anterior si existe
    
    // Sincronizar inmediatamente
    syncWithServer();
    
    // Configurar sincronización automática cada 30 segundos
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_connectivity.isConnected && !_isSyncing) {
        syncWithServer();
      }
    });
  }

  void _stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  // Obtener eventos (siempre desde almacenamiento local)
Future<List<Event>> getEvents() async {
  final events = _localStorage.getAllEvents();
  
  // Si está autenticado y hay conexión, intentar sincronizar
  if (_authService.isAuthenticated && _connectivity.isConnected && !_isSyncing) {
    final unsyncedCount = _localStorage.getUnsyncedEvents().length;
    if (unsyncedCount > 0) {
      print('📊 Found $unsyncedCount unsynced events - triggering sync');
      syncWithServer();
    }
  }
  
  return events;
}

  // Guardar evento (siempre localmente, sincronizar después si hay conexión)
Future<void> saveEvent(Event event) async {
  // Determinar si necesita sincronización basado en autenticación
  final needsSync = _authService.isAuthenticated && _connectivity.isConnected;
  
  final eventToSave = event.copyWith(
    needsSync: needsSync,
    lastModified: DateTime.now(),
  );
  
  await _localStorage.saveEvent(eventToSave);
  print('💾 Event saved locally: ${eventToSave.title} (needsSync: $needsSync)');
  
  // Solo intentar sincronizar si está autenticado
  if (_authService.isAuthenticated && _connectivity.isConnected && !_isSyncing) {
    syncWithServer();
  }
}

  // Eliminar evento
  Future<void> deleteEvent(String eventId) async {
    await _localStorage.deleteEvent(eventId);
    
    // Si hay conexión, intentar sincronizar
    if (_connectivity.isConnected && !_isSyncing) {
      syncWithServer();
    }
  }

  // Eliminar todas las instancias de un evento
  Future<void> deleteAllEventInstances(String eventId) async {
    await deleteEvent(eventId); // Mismo comportamiento por ahora
  }

  // Sincronización con servidor
  Future<void> syncWithServer() async {
    if (_isSyncing) {
      print('⏳ Sync already in progress, skipping...');
      return;
    }
    
    if (!_connectivity.isConnected) {
      print('📴 No connection, skipping sync');
      return;
    }
    
    if (!_authService.isAuthenticated) {
      print('🔒 Not authenticated, skipping sync');
      return;
    }

    _isSyncing = true;
    _syncStatusController.add(SyncStatus.syncing);
    print('🔄 Starting sync process...');
    
    try {
      await _performSync();
      _syncStatusController.add(SyncStatus.synced);
      print('✅ Sync completed successfully');
    } catch (e) {
      _syncStatusController.add(SyncStatus.error);
      print('❌ Sync failed: $e');
      // Agregar más detalles del error
      if (e is PostgrestException) {
        print('❌ Supabase error: ${e.message}, Code: ${e.code}');
      }
    } finally {
      _isSyncing = false;
    }
  }

Future<void> _performSync() async {
  final user = _authService.currentUser;
  if (user == null) {
    throw Exception('User not found during sync');
  }

  print('👤 Syncing for user: ${user.id}');

  // NUEVO: Migrar eventos locales al usuario autenticado
  await _migrateLocalEventsToUser(user.id);
  
  // Continuar con sincronización normal
  await _uploadLocalEvents(user.id);
  await _syncDeletions(user.id);
  await _downloadServerEvents(user.id);
  await _localStorage.cleanupSyncedDeletedEvents();
}

// 6. NUEVA función para migrar eventos locales
Future<void> _migrateLocalEventsToUser(String userId) async {
  final localEvents = _localStorage.getAllEvents()
      .where((event) => event.userId == 'local_user')
      .toList();
  
  if (localEvents.isNotEmpty) {
    print('🔄 Migrating ${localEvents.length} local events to user $userId');
    
    for (final event in localEvents) {
      final migratedEvent = event.copyWith(
        userId: userId,
        needsSync: true,
        lastModified: DateTime.now(),
      );
      
      await _localStorage.saveEvent(migratedEvent);
    }
    
    print('✅ Migration completed');
  }
}


  Future<void> _uploadLocalEvents(String userId) async {
    final unsyncedEvents = _localStorage.getUnsyncedEvents()
        .where((event) => !event.isDeleted)
        .toList();

    print('⬆️ Uploading ${unsyncedEvents.length} unsynced events...');

    for (final event in unsyncedEvents) {
      try {
        // Asegurar que el evento tenga el userId correcto
        final eventToUpload = event.copyWith(
          userId: userId,
          lastModified: DateTime.now(),
        );
        
        print('📤 Uploading event: ${event.title} (ID: ${event.id})');
        
        // Preparar datos para Supabase
        final eventData = eventToUpload.toJson();
        
        // Verificar estructura de datos
        print('📋 Event data structure: ${eventData.keys}');
        
        final response = await supabase
            .from('events')
            .upsert(eventData, 
                onConflict: 'id') // Especificar la columna de conflicto
            .select(); // Agregar select para obtener respuesta
        
        print('✅ Upload response: $response');
        
        await _localStorage.markAsSynced(event.id);
        print('⬆️ Successfully uploaded event: ${event.title}');
        
      } catch (e) {
        print('❌ Failed to upload event ${event.id}: $e');
        
        // Agregar más información del error
        if (e is PostgrestException) {
          print('❌ Supabase error details:');
          print('   Message: ${e.message}');
          print('   Code: ${e.code}');
          print('   Details: ${e.details}');
          print('   Hint: ${e.hint}');
        }
        
        // No lanzar la excepción para que otros eventos puedan sincronizarse
        continue;
      }
    }
  }

  Future<void> _syncDeletions(String userId) async {
    final deletedEvents = _localStorage.getDeletedEvents();
    
    print('🗑️ Syncing ${deletedEvents.length} deleted events...');

    for (final event in deletedEvents) {
      try {
        final _ = await supabase
            .from('events')
            .delete()
            .eq('id', event.id)
            .eq('user_id', userId)
            .select(); // Agregar select para verificar que se eliminó
        
        await _localStorage.markAsSynced(event.id);
        print('🗑️ Deleted event synced: ${event.title}');
      } catch (e) {
        print('❌ Failed to sync deletion for ${event.id}: $e');
        continue;
      }
    }
  }

  Future<void> _downloadServerEvents(String userId) async {
    try {
      print('⬇️ Downloading events from server...');
      
      final response = await supabase
          .from('events')
          .select()
          .eq('user_id', userId);

      print('📥 Server response: ${response.length} events');

      final serverEvents = (response as List)
          .map((json) => Event.fromJson(json))
          .toList();

      // Actualizar eventos locales con datos del servidor
      int updatedCount = 0;
      for (final serverEvent in serverEvents) {
        final localEvent = _localStorage.getEvent(serverEvent.id);
        
        if (localEvent == null || 
            serverEvent.lastModified.isAfter(localEvent.lastModified)) {
          // Evento nuevo o más reciente en el servidor
          final eventToSave = serverEvent.copyWith(needsSync: false);
          await _localStorage.saveEvent(eventToSave);
          updatedCount++;
          print('⬇️ Downloaded/updated event: ${serverEvent.title}');
        }
      }
      
      print('📥 Updated $updatedCount events from server');
      
    } catch (e) {
      print('❌ Failed to download server events: $e');
      rethrow;
    }
  }

  // Forzar sincronización manual
  Future<void> forceSync() async {
    if (!_connectivity.isConnected) {
      throw Exception('No internet connection available');
    }
    
    print('🔄 Force sync requested');
    await syncWithServer();
  }

  // Obtener estado de sincronización
  SyncInfo getSyncInfo() {
    final stats = _localStorage.getStorageStats();
    return SyncInfo(
      isOnline: _connectivity.isConnected,
      totalEvents: stats['active'] ?? 0,
      unsyncedEvents: stats['unsynced'] ?? 0,
      lastSyncTime: null, // TODO: Implementar timestamp del último sync
    );
  }

  void dispose() {
    _stopAutoSync();
    _syncStatusController.close();
  }
}

// Enums y clases auxiliares
enum SyncStatus {
  offline,
  syncing,
  synced,
  error,
}

class SyncInfo {
  final bool isOnline;
  final int totalEvents;
  final int unsyncedEvents;
  final DateTime? lastSyncTime;

  SyncInfo({
    required this.isOnline,
    required this.totalEvents,
    required this.unsyncedEvents,
    this.lastSyncTime,
  });

  bool get hasUnsyncedChanges => unsyncedEvents > 0;
}