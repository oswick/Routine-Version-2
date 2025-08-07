import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';

class ConnectivityIndicator extends StatefulWidget {
  const ConnectivityIndicator({super.key});

  @override
  State<ConnectivityIndicator> createState() => _ConnectivityIndicatorState();
}

class _ConnectivityIndicatorState extends State<ConnectivityIndicator> {
  final ConnectivityService _connectivity = ConnectivityService();
  final SyncService _syncService = SyncService();
  
  bool _isOnline = false;
  SyncStatus _syncStatus = SyncStatus.offline;
  SyncInfo? _syncInfo;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _isOnline = await _connectivity.testInternetConnection();
    _updateSyncInfo();
    
    _connectivity.connectionStream.listen((isConnected) async {
      if (mounted) {
        setState(() {
          _isOnline = isConnected;
        });
        _updateSyncInfo();
      }
    });
    
    _syncService.syncStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _syncStatus = status;
          // Resetear estado de sincronización manual
          if (status == SyncStatus.synced || status == SyncStatus.error) {
            _isSyncing = false;
          }
        });
        _updateSyncInfo();
      }
    });
  }

  void _updateSyncInfo() {
    setState(() {
      _syncInfo = _syncService.getSyncInfo();
    });
  }

  Future<void> _forceSync() async {
    if (_isSyncing) return;
    
    setState(() => _isSyncing = true);
    
    try {
      await _syncService.forceSync();
      
      // Esperar a que se actualice el estado
      await Future.delayed(const Duration(seconds: 1));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Sync completed successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Sync failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOnline) {
      return _buildOfflineIndicator();
    }
    
    // Mostrar estado de sincronización manual
    if (_isSyncing) {
      return _buildSyncingIndicator();
    }
    
    switch (_syncStatus) {
      case SyncStatus.syncing:
        return _buildSyncingIndicator();
      case SyncStatus.error:
        return _buildErrorIndicator();
      case SyncStatus.synced:
        if (_syncInfo?.hasUnsyncedChanges == true) {
          return _buildUnsyncedIndicator();
        }
        return _buildOnlineIndicator();
      case SyncStatus.offline:
        return _buildOfflineIndicator();
    }
  }

  Widget _buildOfflineIndicator() {
    return Container(
      // ... mismo diseño
      child: Row(
        children: [
          Icon(Icons.offline_bolt, size: 16, color: Colors.orange[700]),
          const SizedBox(width: 4),
          const Text('Offline', style: TextStyle()),
          if (_syncInfo?.unsyncedEvents != null && _syncInfo!.unsyncedEvents > 0)
            _buildUnsyncedBadge(),
        ],
      ),
    );
  }

  Widget _buildUnsyncedBadge() {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
      child: Text(
        '${_syncInfo?.unsyncedEvents ?? 0}',
        style: TextStyle(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildOnlineIndicator() {
    return Container(
      // ... mismo diseño
      child: Row(
        children: [
          Icon(Icons.cloud_done, size: 16, color: Colors.green[700]),
          const SizedBox(width: 4),
          const Text('Synced', style: TextStyle()),
        ],
      ),
    );
  }

  Widget _buildSyncingIndicator() {
    return Container(
      // ... mismo diseño
      child: Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.blue[700],
            ),
          ),
          const SizedBox(width: 6),
          const Text('Syncing...', style: TextStyle()),
        ],
      ),
    );
  }

  Widget _buildUnsyncedIndicator() {
    return GestureDetector(
      onTap: _forceSync, // Usar método corregido
      child: Container(
        // ... mismo diseño
        child: Row(
          children: [
            Icon(Icons.sync_problem, size: 16, color: Colors.amber[700]),
            const SizedBox(width: 4),
            Text(
              'Tap to sync (${_syncInfo?.unsyncedEvents ?? 0})',
              style: TextStyle(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorIndicator() {
    return GestureDetector(
      onTap: _forceSync, // Usar método corregido
      child: Container(
        // ... mismo diseño
        child: Row(
          children: [
            Icon(Icons.error, size: 16, color: Colors.red[700]), // Icono diferente
            const SizedBox(width: 4),
            const Text('Sync error', style: TextStyle()),
          ],
        ),
      ),
    );
  }
}