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
        setState(() => _isOnline = isConnected);
        _updateSyncInfo();
      }
    });

    _syncService.syncStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _syncStatus = status;
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
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Sync completed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Sync failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Color indicatorColor;
    String tooltipText;
    VoidCallback? onTap;

    if (!_isOnline) {
      indicatorColor = Colors.grey;
      tooltipText = 'Offline';
    } else if (_isSyncing || _syncStatus == SyncStatus.syncing) {
      indicatorColor = Colors.blue;
      tooltipText = 'Syncing...';
    } else if (_syncStatus == SyncStatus.error) {
      indicatorColor = Colors.red;
      tooltipText = 'Sync error — Tap to retry';
      onTap = _forceSync;
    } else if (_syncInfo?.hasUnsyncedChanges == true) {
      indicatorColor = Colors.amber;
      tooltipText = 'Unsynced changes — Tap to sync';
      onTap = _forceSync;
    } else {
      indicatorColor = Colors.green;
      tooltipText = 'Synced';
    }

    return Tooltip(
      message: tooltipText,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: indicatorColor,
          ),
        ),
      ),
    );
  }
}
