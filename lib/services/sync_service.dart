// lib/services/sync_service.dart
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
        _subscribeToRealtimeChanges();
      } else {
        print('📴 Connection lost - stopping sync');
        _stopAutoSync();
        _unsubscribeFromRealtimeChanges();
        _syncStatusController.add(SyncStatus.offline);
      }
    });

    if (_connectivity.isConnected) {
      _startAutoSync();
      _subscribeToRealtimeChanges();
    }
  }

  void _subscribeToRealtimeChanges() {
    if (!_authService.isAuthenticated) return;
    final userId = _authService.currentUserId;
    if (userId == null) return;

    _unsubscribeFromRealtimeChanges();

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
              print('📡 Realtime change: ${payload.eventType}');
              // FIX: react immediately to remote changes
              _debouncedSync(delay: const Duration(milliseconds: 500));
            },
          )
          .subscribe();

      print('📡 Subscribed to realtime for user $userId');
    } catch (e) {
      print('❌ Failed to subscribe to realtime: $e');
    }
  }

  void _unsubscribeFromRealtimeChanges() {
    if (_realtimeChannel != null) {
      supabase.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
    }
  }

  Timer? _debounceTimer;

  void _debouncedSync({Duration delay = const Duration(seconds: 2)}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () {
      if (!_isSyncing) syncWithServer();
    });
  }

  void _startAutoSync() {
    _stopAutoSync();
    syncWithServer(); // immediate on start

    // FIX: poll every 60 seconds — ensures second device always gets updates
    _syncTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (_connectivity.isConnected && !_isSyncing) {
        syncWithServer();
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

    if (_authService.isAuthenticated &&
        _connectivity.isConnected &&
        !_isSyncing) {
      final timeSinceLastSync = _lastSyncTime != null
          ? DateTime.now().difference(_lastSyncTime!)
          : const Duration(hours: 1);

      if (_lastSyncTime == null ||
          timeSinceLastSync.inSeconds > 60 ||
          _localStorage.getUnsyncedEvents().isNotEmpty) {
        syncWithServer();
      }
    }

    return events;
  }

  Future<void> saveEvent(Event event) async {
    // FIX: always needsSync=true — upload loop must never skip this event
    final eventToSave = event.copyWith(
      needsSync: true,
      lastModified: DateTime.now(),
    );

    await _localStorage.saveEvent(eventToSave);
    print('💾 Saved locally: ${eventToSave.title}');

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
    if (_isSyncing) return;
    if (!_connectivity.isConnected) return;
    if (!_authService.isAuthenticated) return;

    _isSyncing = true;
    _syncStatusController.add(SyncStatus.syncing);
    print('🔄 Sync starting...');

    try {
      await _performSync();
      _lastSyncTime = DateTime.now();
      _syncStatusController.add(SyncStatus.synced);
      print('✅ Sync done at $_lastSyncTime');
    } catch (e) {
      _syncStatusController.add(SyncStatus.error);
      print('❌ Sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _performSync() async {
    final user = _authService.currentUser;
    if (user == null) throw Exception('User not found during sync');

    await _migrateLocalEventsToUser(user.id);
    await _uploadLocalEvents(user.id);
    await _syncDeletions(user.id);
    await _downloadServerEvents(user.id);
    await _localStorage.cleanupSyncedDeletedEvents();
  }

  Future<void> _migrateLocalEventsToUser(String userId) async {
    final local = _localStorage
        .getAllEvents()
        .where((e) => e.userId == 'local_user')
        .toList();

    for (final event in local) {
      await _localStorage.saveEvent(event.copyWith(
        userId: userId,
        needsSync: true,
        lastModified: DateTime.now(),
      ));
    }
  }

  Future<void> _uploadLocalEvents(String userId) async {
    final unsynced = _localStorage
        .getUnsyncedEvents()
        .where((e) => !e.isDeleted)
        .toList();

    print('⬆️ Uploading ${unsynced.length} unsynced events...');

    const batchSize = 10;
    for (var i = 0; i < unsynced.length; i += batchSize) {
      final batch = unsynced.skip(i).take(batchSize).toList();
      await Future.wait(
        batch.map((e) => _uploadSingleEvent(e, userId)),
        eagerError: false,
      );
    }
  }

  Future<void> _uploadSingleEvent(Event event, String userId) async {
    try {
      final toUpload = event.copyWith(
        userId: userId,
        lastModified: DateTime.now(),
      );
      await supabase
          .from('events')
          .upsert(toUpload.toJson(), onConflict: 'id')
          .select();
      await _localStorage.markAsSynced(event.id);
      print('⬆️ Uploaded: ${event.title}');
    } catch (e) {
      print('❌ Upload failed for ${event.id}: $e');
    }
  }

  Future<void> _syncDeletions(String userId) async {
    final deleted = _localStorage.getDeletedEvents();
    for (final event in deleted) {
      try {
        await supabase
            .from('events')
            .delete()
            .eq('id', event.id)
            .eq('user_id', userId)
            .select();
        await _localStorage.markAsSynced(event.id);
      } catch (e) {
        print('❌ Deletion sync failed for ${event.id}: $e');
      }
    }
  }

  Future<void> _downloadServerEvents(String userId) async {
    print('⬇️ Downloading from server...');

    final response = await supabase
        .from('events')
        .select()
        .eq('user_id', userId);

    final serverEvents =
        (response as List).map((json) => Event.fromJson(json)).toList();

    print('📥 Got ${serverEvents.length} events from server');

    int updated = 0;
    for (final serverEvent in serverEvents) {
      final local = _localStorage.getEvent(serverEvent.id);

      // FIX: only keep local if it has unsynced edits newer than server.
      // If local is already synced (needsSync=false), server always wins —
      // another device may have updated it.
      final keepLocal = local != null &&
          local.needsSync &&
          local.lastModified.isAfter(serverEvent.lastModified);

      if (!keepLocal) {
        await _localStorage.saveEvent(serverEvent.copyWith(needsSync: false));
        updated++;
        print('⬇️ Saved from server: ${serverEvent.title}');
      }
    }

    print('📥 Updated $updated events from server');
  }

  Future<void> forceSync() async {
    if (!_connectivity.isConnected) {
      throw Exception('No internet connection');
    }
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

enum SyncStatus { offline, syncing, synced, error }

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