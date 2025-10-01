// lib/services/sync_service.dart - VERSIÓN OPTIMIZADA
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
  DateTime? _lastSyncTime;
  
  // 🆕 NUEVO: Realtime subscription
  RealtimeChannel? _realtimeChannel;
  
  final StreamController<SyncStatus> _syncStatusController = 
      StreamController<SyncStatus>.broadcast();
  
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  Future<void> init() async {
    await _localStorage.init();
    await _connectivity.initialize();
    
    _connectivity.connectionStream.listen((isConnected) {
      if (isConnected) {
        print('🌐 Connection restored - starting sync');
        _startAutoSync();
        _subscribeToRealtimeChanges(); // 🆕 Suscribirse a cambios en tiempo real
      } else {
        print('📴 Connection lost - stopping sync');
        _stopAutoSync();
        _unsubscribeFromRealtimeChanges(); // 🆕 Cancelar suscripción
        _syncStatusController.add(SyncStatus.offline);
      }
    });
    
    if (_connectivity.isConnected) {
      _startAutoSync();
      _subscribeToRealtimeChanges();
    }
  }

  // 🆕 NUEVO: Suscribirse a cambios en tiempo real
  void _subscribeToRealtimeChanges() {
    if (!_authService.isAuthenticated) return;
    
    final userId = _authService.currentUserId;
    if (userId == null) return;

    _unsubscribeFromRealtimeChanges(); // Cancelar suscripción anterior

    try {
      _realtimeChannel = supabase
          .channel('events_changes_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'events',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              print('📡 Realtime change detected: ${payload.eventType}');
              // Sincronizar cuando hay cambios
              _debouncedSync();
            },
          )
          .subscribe();

      print('📡 Subscribed to realtime changes for user $userId');
    } catch (e) {
      print('❌ Failed to subscribe to realtime: $e');
    }
  }

  void _unsubscribeFromRealtimeChanges() {
    if (_realtimeChannel != null) {
      supabase.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
      print('📡 Unsubscribed from realtime changes');
    }
  }

  // 🆕 NUEVO: Debounce para evitar múltiples syncs
  Timer? _debounceTimer;
  void _debouncedSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      if (!_isSyncing) {
        syncWithServer();
      }
    });
  }

  void _startAutoSync() {
    _stopAutoSync();
    
    // Sincronizar inmediatamente
    syncWithServer();
    
    // 🆕 CAMBIADO: De 30 segundos a 5 MINUTOS
    // Con realtime, no necesitamos polling tan frecuente
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_connectivity.isConnected && !_isSyncing) {
        // Solo sincronizar si hay cambios sin sincronizar
        final unsyncedCount = _localStorage.getUnsyncedEvents().length;
        if (unsyncedCount > 0) {
          print('📊 Found $unsyncedCount unsynced events - syncing...');
          syncWithServer();
        } else {
          print('✅ No unsynced events, skipping sync');
        }
      }
    });
  }

  void _stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  Future<List<Event>> getEvents() async {
    final events = _localStorage.getAllEvents();
    
    // 🆕 OPTIMIZADO: Solo sincronizar si hace más de 1 minuto desde última sync
    if (_authService.isAuthenticated && 
        _connectivity.isConnected && 
        !_isSyncing) {
      
      final unsyncedCount = _localStorage.getUnsyncedEvents().length;
      final timeSinceLastSync = _lastSyncTime != null 
          ? DateTime.now().difference(_lastSyncTime!)
          : const Duration(hours: 1);
      
      // Sincronizar si:
      // 1. Hay eventos sin sincronizar, O
      // 2. Han pasado más de 5 minutos desde la última sync
      if (unsyncedCount > 0 || timeSinceLastSync.inMinutes > 5) {
        print('📊 Triggering sync: unsynced=$unsyncedCount, timeSinceLastSync=${timeSinceLastSync.inMinutes}min');
        syncWithServer();
      }
    }
    
    return events;
  }

  Future<void> saveEvent(Event event) async {
    final needsSync = _authService.isAuthenticated && _connectivity.isConnected;
    
    final eventToSave = event.copyWith(
      needsSync: needsSync,
      lastModified: DateTime.now(),
    );
    
    await _localStorage.saveEvent(eventToSave);
    print('💾 Event saved locally: ${eventToSave.title} (needsSync: $needsSync)');
    
    // 🆕 OPTIMIZADO: Usar debounce para evitar múltiples syncs rápidos
    if (_authService.isAuthenticated && _connectivity.isConnected) {
      _debouncedSync();
    }
  }

  Future<void> deleteEvent(String eventId) async {
    await _localStorage.deleteEvent(eventId);
    
    if (_connectivity.isConnected && !_isSyncing) {
      _debouncedSync();
    }
  }

  Future<void> deleteAllEventInstances(String eventId) async {
    await deleteEvent(eventId);
  }

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
      _lastSyncTime = DateTime.now();
      _syncStatusController.add(SyncStatus.synced);
      print('✅ Sync completed successfully at $_lastSyncTime');
    } catch (e) {
      _syncStatusController.add(SyncStatus.error);
      print('❌ Sync failed: $e');
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

    await _migrateLocalEventsToUser(user.id);
    await _uploadLocalEvents(user.id);
    await _syncDeletions(user.id);
    await _downloadServerEvents(user.id);
    await _localStorage.cleanupSyncedDeletedEvents();
  }

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

    // 🆕 OPTIMIZADO: Procesar en lotes de 10
    const batchSize = 10;
    for (var i = 0; i < unsyncedEvents.length; i += batchSize) {
      final batch = unsyncedEvents.skip(i).take(batchSize).toList();
      
      await Future.wait(
        batch.map((event) => _uploadSingleEvent(event, userId)),
        eagerError: false, // No detener si uno falla
      );
    }
  }

  Future<void> _uploadSingleEvent(Event event, String userId) async {
    try {
      final eventToUpload = event.copyWith(
        userId: userId,
        lastModified: DateTime.now(),
      );
      
      print('📤 Uploading event: ${event.title} (ID: ${event.id})');
      
      final eventData = eventToUpload.toJson();
      
      await supabase
          .from('events')
          .upsert(eventData, onConflict: 'id')
          .select();
      
      await _localStorage.markAsSynced(event.id);
      print('⬆️ Successfully uploaded event: ${event.title}');
      
    } catch (e) {
      print('❌ Failed to upload event ${event.id}: $e');
      if (e is PostgrestException) {
        print('❌ Supabase error details:');
        print('   Message: ${e.message}');
        print('   Code: ${e.code}');
      }
    }
  }

  Future<void> _syncDeletions(String userId) async {
    final deletedEvents = _localStorage.getDeletedEvents();
    
    print('🗑️ Syncing ${deletedEvents.length} deleted events...');

    for (final event in deletedEvents) {
      try {
        await supabase
            .from('events')
            .delete()
            .eq('id', event.id)
            .eq('user_id', userId)
            .select();
        
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

      int updatedCount = 0;
      for (final serverEvent in serverEvents) {
        final localEvent = _localStorage.getEvent(serverEvent.id);
        
        if (localEvent == null || 
            serverEvent.lastModified.isAfter(localEvent.lastModified)) {
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

  Future<void> forceSync() async {
    if (!_connectivity.isConnected) {
      throw Exception('No internet connection available');
    }
    
    print('🔄 Force sync requested');
    await syncWithServer();
  }

  SyncInfo getSyncInfo() {
    final stats = _localStorage.getStorageStats();
    return SyncInfo(
      isOnline: _connectivity.isConnected,
      totalEvents: stats['active'] ?? 0,
      unsyncedEvents: stats['unsynced'] ?? 0,
      lastSyncTime: _lastSyncTime,
    );
  }

  void dispose() {
    _stopAutoSync();
    _unsubscribeFromRealtimeChanges();
    _syncStatusController.close();
  }
}

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