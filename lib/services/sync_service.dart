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
  Timer? _debounceTimer;
  Timer? _uploadTimer;
  bool _isSyncing = false;
  bool _isInitialized = false;
  DateTime? _lastSyncTime;
  RealtimeChannel? _realtimeChannel;
  StreamSubscription<bool>? _connectivitySubscription;
  StreamSubscription<AuthState>? _authSubscription;

  // IDs written by this client. Realtime echoes for these IDs are ignored.
  // Unlike a time-based counter, this cannot accidentally suppress unrelated
  // remote changes just because a network request took longer than expected.
  final Set<String> _locallyWrittenEventIds = <String>{};

  final StreamController<SyncStatus> _syncStatusController =
      StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  final StreamController<List<Event>> _remoteChangesController =
      StreamController<List<Event>>.broadcast();
  Stream<List<Event>> get remoteChangesStream =>
      _remoteChangesController.stream;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await _localStorage.init();
    await _connectivity.initialize();

    _connectivitySubscription = _connectivity.connectionStream.listen(
      _handleConnectivityChange,
    );

    _authSubscription = _authService.authStateChanges.listen(
      _handleAuthStateChange,
    );

    if (_connectivity.isConnected) {
      _startAutoSync();
      await _refreshRealtimeSubscription();
    }
  }

  Future<void> _handleConnectivityChange(bool isConnected) async {
    if (isConnected) {
      _startAutoSync();
      await _refreshRealtimeSubscription();
    } else {
      _stopAutoSync();
      await _unsubscribeFromRealtimeChanges();
      _syncStatusController.add(SyncStatus.offline);
    }
  }

  Future<void> _handleAuthStateChange(AuthState state) async {
    switch (state.event) {
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.tokenRefreshed:
      case AuthChangeEvent.userUpdated:
        await _refreshRealtimeSubscription();
        if (_connectivity.isConnected) {
          await _syncRemoteOnly();
        }
        break;
      case AuthChangeEvent.signedOut:
        await _unsubscribeFromRealtimeChanges();
        _stopAutoSync();
        break;
      default:
        break;
    }
  }

  /// Rebuilds the user-filtered Realtime channel using the current Supabase
  /// session. This is safe to call after login, logout, token refresh, or
  /// reconnecting to the network.
  Future<void> refreshRealtimeSubscription() async {
    await _refreshRealtimeSubscription();
  }

  Future<void> _refreshRealtimeSubscription() async {
    await _unsubscribeFromRealtimeChanges();

    if (!_connectivity.isConnected || !_authService.isAuthenticated) return;

    final userId = _authService.currentUserId;
    if (userId == null) return;

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
              final eventId = _eventIdFromPayload(payload);
              if (eventId != null && _locallyWrittenEventIds.contains(eventId)) {
                print('📡 Realtime: own-write echo suppressed for $eventId');
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

  String? _eventIdFromPayload(PostgresPostgresChangePayload payload) {
    final newRecord = payload.newRecord;
    final oldRecord = payload.oldRecord;
    return newRecord['id']?.toString() ?? oldRecord['id']?.toString();
  }

  Future<void> _unsubscribeFromRealtimeChanges() async {
    final channel = _realtimeChannel;
    _realtimeChannel = null;
    if (channel != null) {
      try {
        await supabase.removeChannel(channel);
      } catch (e) {
        print('⚠️ Failed to remove Realtime channel: $e');
      }
    }
  }

  void _debouncedRemoteSync({
    Duration delay = const Duration(milliseconds: 400),
  }) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () {
      if (!_isSyncing) {
        unawaited(_syncRemoteOnly());
      }
    });
  }

  void _debouncedUpload({
    Duration delay = const Duration(milliseconds: 300),
  }) {
    _uploadTimer?.cancel();
    _uploadTimer = Timer(delay, () {
      if (!_isSyncing) {
        unawaited(_syncRemoteOnly());
      }
    });
  }

  void _startAutoSync() {
    _stopAutoSync();
    if (_authService.isAuthenticated) {
      unawaited(_syncRemoteOnly());
    }
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_connectivity.isConnected &&
          _authService.isAuthenticated &&
          !_isSyncing) {
        unawaited(_syncRemoteOnly());
      }
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

  List<Event> getLocalEvents() => _localStorage.getAllEvents();

  Future<List<Event>> getEvents() async {
    final events = _localStorage.getAllEvents();
    if (_authService.isAuthenticated &&
        _connectivity.isConnected &&
        !_isSyncing) {
      unawaited(_syncRemoteOnly());
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
      _locallyWrittenEventIds.add(eventToSave.id);
      _debouncedUpload();
    }
  }

  Future<void> deleteEvent(String eventId) async {
    await _localStorage.deleteEvent(eventId);
    if (_authService.isAuthenticated && _connectivity.isConnected) {
      _locallyWrittenEventIds.add(eventId);
      _debouncedUpload();
    }
  }

  Future<void> deleteAllEventInstances(String eventId) => deleteEvent(eventId);

  Future<void> forceSync() async {
    if (!_connectivity.isConnected) {
      throw Exception('No internet connection');
    }
    if (!_authService.isAuthenticated) return;
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
    unawaited(_unsubscribeFromRealtimeChanges());
    unawaited(_connectivitySubscription?.cancel());
    unawaited(_authSubscription?.cancel());
    _connectivitySubscription = null;
    _authSubscription = null;
    _syncStatusController.close();
    _remoteChangesController.close();
    _isInitialized = false;
  }

  Future<void> _syncRemoteOnly() async {
    if (_isSyncing ||
        !_connectivity.isConnected ||
        !_authService.isAuthenticated) {
      return;
    }

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

  Future<void> _migrateLocalEventsToUser(String userId) async {
    final local = _localStorage
        .getAllEvents()
        .where((e) => e.userId == 'local_user')
        .toList();

    for (final event in local) {
      // Keep the original local modification time. Authentication migration
      // changes ownership, not the event's actual modification time.
      await _localStorage.saveEvent(event.copyWith(
        userId: userId,
        needsSync: true,
        lastModified: event.lastModified,
      ));
      _locallyWrittenEventIds.add(event.id);
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
      await Future.wait(batch.map((e) => _uploadSingleEvent(e, userId)));
    }
  }

  Future<void> _uploadSingleEvent(Event event, String userId) async {
    try {
      // IMPORTANT: never replace lastModified during upload. It represents
      // when the user actually modified the event on the local device.
      final toUpload = event.copyWith(
        userId: userId,
        lastModified: event.lastModified,
        needsSync: true,
      );

      await supabase
          .from('events')
          .upsert(toUpload.toJson(), onConflict: 'id')
          .select();

      await _localStorage.markAsSynced(event.id);
      _locallyWrittenEventIds.remove(event.id);
      print('⬆️ Uploaded: ${event.title}');
    } catch (e) {
      print('❌ Upload failed for ${event.id}: $e');
      rethrow;
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
        _locallyWrittenEventIds.remove(event.id);
      } catch (e) {
        print('❌ Deletion sync failed for ${event.id}: $e');
        rethrow;
      }
    }
  }

  Future<List<Event>> _downloadServerEvents(String userId) async {
    print('⬇️ Downloading from server…');
    final response = await supabase.from('events').select().eq('user_id', userId);
    final serverEvents =
        (response as List).map((json) => Event.fromJson(json)).toList();
    print('📥 Server: ${serverEvents.length} events');

    final List<Event> changed = [];

    for (final serverEvent in serverEvents) {
      final local = _localStorage.getEvent(serverEvent.id);

      if (local != null &&
          local.needsSync &&
          local.lastModified.isAfter(serverEvent.lastModified)) {
        continue;
      }

      final isDifferent = local == null ||
          local.lastModified != serverEvent.lastModified ||
          local.title != serverEvent.title ||
          local.description != serverEvent.description ||
          local.startTime != serverEvent.startTime ||
          local.endTime != serverEvent.endTime ||
          !_sameIntList(local.repeatDays, serverEvent.repeatDays) ||
          local.importance != serverEvent.importance ||
          local.category != serverEvent.category ||
          local.isCompleted != serverEvent.isCompleted ||
          local.userId != serverEvent.userId;

      if (isDifferent) {
        await _localStorage.saveEvent(serverEvent.copyWith(needsSync: false));
        changed.add(serverEvent);
        print('⬇️ Updated from server: ${serverEvent.title}');
      } else if (local.needsSync) {
        await _localStorage.markAsSynced(serverEvent.id);
      }
    }

    final serverIds = serverEvents.map((e) => e.id).toSet();
    for (final local in _localStorage.getAllEvents()) {
      if (!serverIds.contains(local.id) &&
          !local.needsSync &&
          !local.isDeleted &&
          local.userId == userId) {
        await _localStorage.deleteEvent(local.id, permanent: true);
        changed.add(local.copyWith(isDeleted: true));
        print('🗑️ Removed locally (deleted on server): ${local.id}');
      }
    }

    return changed;
  }

  bool _sameIntList(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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
