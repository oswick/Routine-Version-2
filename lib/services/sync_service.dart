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

  // While > 0, Realtime echoes of our own writes are suppressed.
  int _localWriteInProgress = 0;

  // ── Streams ───────────────────────────────────────────────────────────────
  final StreamController<SyncStatus> _syncStatusController =
      StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  // Emits ONLY when the server sent us events from another device.
  // Carries the list of changed/deleted events so EventProvider can merge
  // them into its in-memory list surgically (no full reload needed).
  final StreamController<List<Event>> _remoteChangesController =
      StreamController<List<Event>>.broadcast();
  Stream<List<Event>> get remoteChangesStream =>
      _remoteChangesController.stream;

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    await _localStorage.init();
    await _connectivity.initialize();

    _connectivity.connectionStream.listen((isConnected) {
      if (isConnected) {
        _startAutoSync();
        _subscribeToRealtimeChanges();
      } else {
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

  // ── Realtime ──────────────────────────────────────────────────────────────
  void _subscribeToRealtimeChanges() {
    if (!_authService.isAuthenticated) return;
    final userId = _authService.currentUserId;
    if (userId == null) return;

    _unsubscribeFromRealtimeChanges();

    try {
      _realtimeChannel = supabase
          .channel('events_realtime_$userId')
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
              if (_localWriteInProgress > 0) {
                print('📡 Realtime: own-write echo suppressed');
                return;
              }
              print('📡 Realtime: remote change – syncing');
              _debouncedRemoteSync();
            },
          )
          .subscribe((status, _) {
            print('📡 Realtime channel: $status');
            if (status == RealtimeSubscribeStatus.subscribed) {
              _debouncedRemoteSync(delay: const Duration(milliseconds: 500));
            }
          });

      print('📡 Subscribed to Realtime for user $userId');
    } catch (e) {
      print('❌ Failed to subscribe to Realtime: $e');
    }
  }

  void _unsubscribeFromRealtimeChanges() {
    if (_realtimeChannel != null) {
      supabase.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
    }
  }

  // ── Debounce helpers ──────────────────────────────────────────────────────
  Timer? _debounceTimer;
  Timer? _uploadTimer;

  void _debouncedRemoteSync(
      {Duration delay = const Duration(milliseconds: 400)}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () {
      if (!_isSyncing) _syncRemoteOnly();
    });
  }

  void _debouncedUpload(
      {Duration delay = const Duration(milliseconds: 300)}) {
    _uploadTimer?.cancel();
    _uploadTimer = Timer(delay, () {
      if (!_isSyncing) _uploadPendingEvents();
    });
  }

  // ── Auto-sync (fallback poll) ─────────────────────────────────────────────
  void _startAutoSync() {
    _stopAutoSync();
    _syncRemoteOnly();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_connectivity.isConnected && !_isSyncing) _syncRemoteOnly();
    });
  }

  void _stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _uploadTimer?.cancel();
    _uploadTimer = null;
  }

  // ── Public API ────────────────────────────────────────────────────────────
  List<Event> getLocalEvents() => _localStorage.getAllEvents();

  Future<List<Event>> getEvents() async {
    final events = _localStorage.getAllEvents();
    if (_authService.isAuthenticated &&
        _connectivity.isConnected &&
        !_isSyncing) {
      _syncRemoteOnly();
    }
    return events;
  }

  Future<void> saveEvent(Event event) async {
    final eventToSave = event.copyWith(
      needsSync: true,
      lastModified: DateTime.now(),
    );
    await _localStorage.saveEvent(eventToSave);
    print('💾 Saved locally: ${eventToSave.title}');

    if (_authService.isAuthenticated && _connectivity.isConnected) {
      _localWriteInProgress++;
      _debouncedUpload();
      Future.delayed(const Duration(seconds: 3), () {
        _localWriteInProgress = (_localWriteInProgress - 1).clamp(0, 999);
      });
    }
  }

  Future<void> deleteEvent(String eventId) async {
    await _localStorage.deleteEvent(eventId);
    if (_connectivity.isConnected) {
      _localWriteInProgress++;
      _debouncedUpload();
      Future.delayed(const Duration(seconds: 3), () {
        _localWriteInProgress = (_localWriteInProgress - 1).clamp(0, 999);
      });
    }
  }

  Future<void> deleteAllEventInstances(String eventId) =>
      deleteEvent(eventId);

  Future<void> forceSync() async {
    if (!_connectivity.isConnected) throw Exception('No internet connection');
    await _syncRemoteOnly();
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
    _remoteChangesController.close();
  }

  // ── Upload-only (local → server, no UI notification) ─────────────────────
  Future<void> _uploadPendingEvents() async {
    if (!_authService.isAuthenticated || !_connectivity.isConnected) return;
    final user = _authService.currentUser;
    if (user == null) return;

    _syncStatusController.add(SyncStatus.syncing);
    try {
      await _migrateLocalEventsToUser(user.id);
      await _uploadLocalEvents(user.id);
      await _syncDeletions(user.id);
      _lastSyncTime = DateTime.now();
      _syncStatusController.add(SyncStatus.synced);
      print('⬆️ Upload done');
    } catch (e) {
      _syncStatusController.add(SyncStatus.error);
      print('❌ Upload failed: $e');
    }
  }

  // ── Remote sync (server → local → UI) ────────────────────────────────────
  Future<void> _syncRemoteOnly() async {
    if (_isSyncing) return;
    if (!_connectivity.isConnected || !_authService.isAuthenticated) return;

    _isSyncing = true;
    _syncStatusController.add(SyncStatus.syncing);
    print('🔄 Remote sync starting…');

    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('No user');

      await _migrateLocalEventsToUser(user.id);
      await _uploadLocalEvents(user.id);
      await _syncDeletions(user.id);

      final changed = await _downloadServerEvents(user.id);
      await _localStorage.cleanupSyncedDeletedEvents();

      _lastSyncTime = DateTime.now();
      _syncStatusController.add(SyncStatus.synced);
      print('✅ Remote sync done (${changed.length} changes)');

      if (changed.isNotEmpty) {
        _remoteChangesController.add(changed);
      }
    } catch (e) {
      _syncStatusController.add(SyncStatus.error);
      print('❌ Remote sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // ── Internals ─────────────────────────────────────────────────────────────
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
    if (unsynced.isEmpty) return;
    print('⬆️ Uploading ${unsynced.length} events…');
    const batchSize = 10;
    for (var i = 0; i < unsynced.length; i += batchSize) {
      final batch = unsynced.skip(i).take(batchSize).toList();
      await Future.wait(
          batch.map((e) => _uploadSingleEvent(e, userId)),
          eagerError: false);
    }
  }

  Future<void> _uploadSingleEvent(Event event, String userId) async {
    try {
      final toUpload =
          event.copyWith(userId: userId, lastModified: DateTime.now());
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

  // Returns only events genuinely changed by a remote device.
  Future<List<Event>> _downloadServerEvents(String userId) async {
    print('⬇️ Downloading from server…');
    final response =
        await supabase.from('events').select().eq('user_id', userId);
    final serverEvents =
        (response as List).map((json) => Event.fromJson(json)).toList();
    print('📥 Server: ${serverEvents.length} events');

    final List<Event> changed = [];

    for (final serverEvent in serverEvents) {
      final local = _localStorage.getEvent(serverEvent.id);

      // Our own unsynced edits take priority if they are newer.
      if (local != null &&
          local.needsSync &&
          local.lastModified.isAfter(serverEvent.lastModified)) {
        continue;
      }

      // Only treat as changed if the data is meaningfully different.
      final isDifferent = local == null ||
          local.lastModified.isBefore(
              serverEvent.lastModified.subtract(const Duration(seconds: 1))) ||
          local.isCompleted != serverEvent.isCompleted ||
          local.title != serverEvent.title;

      if (isDifferent) {
        await _localStorage.saveEvent(serverEvent.copyWith(needsSync: false));
        changed.add(serverEvent);
        print('⬇️ Updated from server: ${serverEvent.title}');
      } else if (local.needsSync) {
        await _localStorage.markAsSynced(serverEvent.id);
      }
    }

    // Detect server-side deletions.
    final serverIds = serverEvents.map((e) => e.id).toSet();
    for (final local in _localStorage.getAllEvents()) {
      if (!serverIds.contains(local.id) &&
          !local.needsSync &&
          !local.isDeleted) {
        await _localStorage.deleteEvent(local.id, permanent: true);
        changed.add(local.copyWith(isDeleted: true));
        print('🗑️ Removed locally (deleted on server): ${local.id}');
      }
    }

    return changed;
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