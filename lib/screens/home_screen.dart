// lib/screens/home_screen.dart

import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/event.dart';
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

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final AuthService _authService = AuthService();
  final ConnectivityService _connectivity = ConnectivityService();

  DateTime selectedDate = DateTime.now();

  bool _isOnline = false;
  SyncStatus _syncStatus = SyncStatus.offline;
  SyncInfo? _syncInfo;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();

    _initConnectivity();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final eventProvider = Provider.of<EventProvider>(
        context,
        listen: false,
      );

      if (eventProvider.events.isEmpty) {
        _refreshEvents();
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initConnectivity() async {
    _isOnline = await _connectivity.testInternetConnection();

    final syncService = SyncService();
    _syncInfo = syncService.getSyncInfo();

    if (mounted) {
      setState(() {});
    }

    _connectivity.connectionStream.listen((isConnected) {
      if (!mounted) return;

      if (_isOnline != isConnected) {
        setState(() {
          _isOnline = isConnected;
        });
      }
    });

    syncService.syncStatusStream.listen((status) {
      if (!mounted) return;

      if (_syncStatus != status) {
        setState(() {
          _syncStatus = status;

          if (status == SyncStatus.synced ||
              status == SyncStatus.error) {
            _isSyncing = false;
          }
        });
      }
    });
  }

  Future<void> _refreshEvents() async {
    if (!mounted) return;

    final eventProvider = Provider.of<EventProvider>(
      context,
      listen: false,
    );

    await eventProvider.loadEvents();
  }

  Color _getConnectivityBorderColor() {
    if (!_isOnline) return Colors.grey;

    if (_isSyncing || _syncStatus == SyncStatus.syncing) {
      return Colors.blue;
    }

    if (_syncStatus == SyncStatus.error) {
      return Colors.red;
    }

    if (_syncInfo?.hasUnsyncedChanges == true) {
      return Colors.amber;
    }

    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final user = _authService.currentUser;

    return Consumer<EventProvider>(
      builder: (context, eventProvider, child) {
        // IMPORTANTE:
        // No usamos ningún cache local aquí.
        //
        // Cada vez que EventProvider hace notifyListeners(),
        // obtenemos nuevamente los eventos del día.
        final dailyEvents = eventProvider
            .getEventsForDay(selectedDate)
            .toList();

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,

          appBar: _buildAppBar(
            context,
            user,
          ),

          body: M3ERefreshIndicator.contained(
            onRefresh: _refreshEvents,
            child: eventProvider.isLoading && dailyEvents.isEmpty
                ? const Center(
                    child: M3ELoadingIndicator(),
                  )
                : _buildDayScreen(
                    dailyEvents,
                  ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    dynamic user,
  ) {
      return M3EAppBar.top(
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
              '${selectedDate.day} - '
              '${selectedDate.month.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),

      actions: [
        if (user != null)
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Container(
              padding: const EdgeInsets.all(2),

              decoration: BoxDecoration(
                shape: BoxShape.circle,

                border: Border.all(
                  color: _getConnectivityBorderColor(),
                  width: 2.5,
                ),
              ),

              child: CircleAvatar(
                radius: 18,

                backgroundImage:
                    user.userMetadata?['avatar_url'] != null
                        ? NetworkImage(
                            user.userMetadata!['avatar_url'],
                          )
                        : null,

                backgroundColor: Theme.of(context)
                    .colorScheme
                    .primary
                    .withOpacity(0.2),

                child:
                    user.userMetadata?['avatar_url'] == null
                        ? Text(
                            user.userMetadata?['full_name']
                                    ?.toString()
                                    .substring(0, 1)
                                    .toUpperCase() ??
                                user.email
                                    ?.substring(0, 1)
                                    .toUpperCase() ??
                                'U',

                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDayScreen(
    List<Event> dailyEvents,
  ) {
    return DayScreen(
      day: selectedDate,
      events: dailyEvents,

      onAddEvent: (event) async {
        final eventProvider = Provider.of<EventProvider>(
          context,
          listen: false,
        );

        await eventProvider.addEvent(event);
      },

      onUpdateEvent: (
        index,
        updatedEvent,
      ) async {
        final eventProvider = Provider.of<EventProvider>(
          context,
          listen: false,
        );

        await eventProvider.updateEvent(
          updatedEvent,
        );
      },

      onDeleteEvent: (
        index,
        allDays,
      ) async {
        if (index < 0 || index >= dailyEvents.length) {
          return;
        }

        final event = dailyEvents[index];

        final eventProvider = Provider.of<EventProvider>(
          context,
          listen: false,
        );

        await eventProvider.deleteEvent(
          event.id,
          deleteAll: allDays,
        );
      },
    );
  }

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