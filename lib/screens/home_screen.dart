// lib/screens/home_screen.dart - Versión actualizada con Provider
import 'package:flutter/material.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/event_provider.dart';
import 'package:myapp/services/auth_service.dart';
import 'package:myapp/services/connectivity_service.dart';
import 'package:myapp/services/sync_service.dart';
import 'day_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  DateTime selectedDate = DateTime.now();

  bool _isOnline = false;
  SyncStatus _syncStatus = SyncStatus.offline;
  SyncInfo? _syncInfo;
  bool _isSyncing = false;
  final ConnectivityService _connectivity = ConnectivityService();

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshEvents();
    });
  }

  Color _getConnectivityBorderColor() {
    if (!_isOnline) return Colors.grey;
    if (_isSyncing || _syncStatus == SyncStatus.syncing) return Colors.blue;
    if (_syncStatus == SyncStatus.error) return Colors.red;
    if (_syncInfo?.hasUnsyncedChanges == true) return Colors.amber;
    return Colors.green;
  }

  void _initConnectivity() async {
    _isOnline = await _connectivity.testInternetConnection();
    final syncService = SyncService();
    _syncInfo = syncService.getSyncInfo();

    setState(() {});

    _connectivity.connectionStream.listen((isConnected) {
      if (mounted) {
        setState(() => _isOnline = isConnected);
      }
    });

    syncService.syncStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _syncStatus = status;
          if (status == SyncStatus.synced || status == SyncStatus.error) {
            _isSyncing = false;
          }
        });
      }
    });
  }

  Future<void> _refreshEvents() async {
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    await eventProvider.loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Consumer<EventProvider>(
      builder: (context, eventProvider, child) {
        final dailyEvents = eventProvider.getEventsForDay(selectedDate);

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 0,
            title: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    getDayName(selectedDate.weekday),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '${selectedDate.day} - ${selectedDate.month.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              // Indicador de conectividad
              if (user != null) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Container(
                    padding: const EdgeInsets.all(2), // Borde exterior
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _getConnectivityBorderColor(),
                        width: 2.5,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundImage: user.userMetadata?['avatar_url'] != null
                          ? NetworkImage(user.userMetadata!['avatar_url'])
                          : null,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.2),
                      child: user.userMetadata?['avatar_url'] == null
                          ? Text(
                              user.userMetadata?['full_name']
                                      ?.toString()
                                      .substring(0, 1)
                                      .toUpperCase() ??
                                  user.email?.substring(0, 1).toUpperCase() ??
                                  'U',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refreshEvents,
            child: eventProvider.isLoading && dailyEvents.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : DayScreen(
                    day: selectedDate,
                    events: dailyEvents,
                    onAddEvent: (event) async {
                      await eventProvider.addEvent(event);
                    },
                    onUpdateEvent: (index, updatedEvent) async {
                      await eventProvider.updateEvent(updatedEvent);
                    },
                    onDeleteEvent: (index, allDays) async {
                      if (index >= 0 && index < dailyEvents.length) {
                        final event = dailyEvents[index];
                        await eventProvider.deleteEvent(
                          event.id,
                          deleteAll: allDays,
                        );
                      }
                    },
                  ),
          ),
        );
      },
    );
  }

  // Reemplaza el método getDayName en home_screen.dart con este:

  String getDayName(int dayOfWeek) {
    final localizations = AppLocalizations.of(context);
    switch (dayOfWeek) {
      case 1:
        return localizations.monday;
      case 2:
        return localizations.tuesday;
      case 3:
        return localizations.wednesday;
      case 4:
        return localizations.thursday;
      case 5:
        return localizations.friday;
      case 6:
        return localizations.saturday;
      case 7:
        return localizations.sunday;
      default:
        return '';
    }
  }
}
