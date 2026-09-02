// lib/screens/home_screen.dart - VERSIÓN OPTIMIZADA
import 'package:flutter/material.dart';
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
  // 🆕 Mantener estado entre navegaciones
  @override
  bool get wantKeepAlive => true;

  final AuthService _authService = AuthService();
  DateTime selectedDate = DateTime.now();

  // 🆕 Estados para conectividad (con cache)
  bool _isOnline = false;
  SyncStatus _syncStatus = SyncStatus.offline;
  SyncInfo? _syncInfo;
  bool _isSyncing = false;
  final ConnectivityService _connectivity = ConnectivityService();

  // 🆕 Cache de eventos del día para evitar recalcular
  List<dynamic>? _cachedDailyEvents;
  DateTime? _cachedDate;

  @override
  void initState() {
    super.initState();
    _initConnectivity();

    // 🆕 OPTIMIZADO: Solo cargar si realmente es necesario
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      if (eventProvider.events.isEmpty) {
        _refreshEvents();
      }
    });
  }

  @override
  void dispose() {
    // Limpiar cache
    _cachedDailyEvents = null;
    _cachedDate = null;
    super.dispose();
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

    if (mounted) setState(() {});

    // 🆕 OPTIMIZADO: Throttle de actualizaciones de conectividad
    _connectivity.connectionStream.listen((isConnected) {
      if (mounted && _isOnline != isConnected) {
        setState(() => _isOnline = isConnected);
      }
    });

    syncService.syncStatusStream.listen((status) {
      if (mounted && _syncStatus != status) {
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

    // 🆕 Invalidar cache después de refresh
    _cachedDailyEvents = null;
    _cachedDate = null;
  }

  // 🆕 NUEVO: Obtener eventos con cache
  List<dynamic> _getCachedDailyEvents(EventProvider provider) {
    // Si la fecha cambió, invalidar cache
    if (_cachedDate == null ||
        _cachedDate!.year != selectedDate.year ||
        _cachedDate!.month != selectedDate.month ||
        _cachedDate!.day != selectedDate.day) {
      _cachedDailyEvents = provider.getEventsForDay(selectedDate);
      _cachedDate = selectedDate;
    }

    return _cachedDailyEvents ?? [];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 🆕 Necesario para AutomaticKeepAliveClientMixin

    final user = _authService.currentUser;

    // 🆕 OPTIMIZADO: Usar Selector en lugar de Consumer para rebuilds específicos
    return Selector<EventProvider, _EventsState>(
      selector: (_, provider) => _EventsState(
        isLoading: provider.isLoading,
        eventsCount: provider.events.length,
        // 🆕 Solo trigger rebuild si los eventos del día específico cambiaron
        eventsHash: _getEventsHashForDate(provider, selectedDate),
      ),
      shouldRebuild: (prev, next) {
        // 🆕 Solo rebuild si realmente cambió algo relevante
        return prev.isLoading != next.isLoading ||
            prev.eventsCount != next.eventsCount ||
            prev.eventsHash != next.eventsHash;
      },
      builder: (context, state, child) {
        final eventProvider = Provider.of<EventProvider>(
          context,
          listen: false,
        );
        final dailyEvents = _getCachedDailyEvents(eventProvider);

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: _buildAppBar(context, user),
          // DESPUÉS
          body: M3ERefreshIndicator.contained(
            onRefresh: _refreshEvents,
            child: state.isLoading && dailyEvents.isEmpty
                ? const Center(child: M3ELoadingIndicator())
                : _buildDayScreen(dailyEvents),
          ),
        );
      },
    );
  }

  // 🆕 NUEVO: Calcular hash de eventos para detectar cambios reales
  int _getEventsHashForDate(EventProvider provider, DateTime date) {
    final events = provider.getEventsForDay(date);
    // Simple hash basado en IDs y timestamps
    return events.fold(0, (hash, event) {
      return hash ^ event.id.hashCode ^ event.lastModified.hashCode;
    });
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, dynamic user) {
    return AppBar(
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
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (user != null) ...[
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
    );
  }

  Widget _buildDayScreen(List<dynamic> dailyEvents) {
    return DayScreen(
      day: selectedDate,
      events: dailyEvents.map((e) => e as Event).toList(),
      onAddEvent: (event) async {
        final eventProvider = Provider.of<EventProvider>(
          context,
          listen: false,
        );
        await eventProvider.addEvent(event);
        // Invalidar cache después de agregar
        _cachedDailyEvents = null;
      },
      onUpdateEvent: (index, updatedEvent) async {
        final eventProvider = Provider.of<EventProvider>(
          context,
          listen: false,
        );
        await eventProvider.updateEvent(updatedEvent);
        // Invalidar cache después de actualizar
        _cachedDailyEvents = null;
      },
      onDeleteEvent: (index, allDays) async {
        if (index >= 0 && index < dailyEvents.length) {
          final event = dailyEvents[index];
          final eventProvider = Provider.of<EventProvider>(
            context,
            listen: false,
          );
          await eventProvider.deleteEvent(event.id, deleteAll: allDays);
          // Invalidar cache después de eliminar
          _cachedDailyEvents = null;
        }
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

// 🆕 NUEVO: Clase para estado inmutable de eventos
class _EventsState {
  final bool isLoading;
  final int eventsCount;
  final int eventsHash;

  const _EventsState({
    required this.isLoading,
    required this.eventsCount,
    required this.eventsHash,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _EventsState &&
          runtimeType == other.runtimeType &&
          isLoading == other.isLoading &&
          eventsCount == other.eventsCount &&
          eventsHash == other.eventsHash;

  @override
  int get hashCode =>
      isLoading.hashCode ^ eventsCount.hashCode ^ eventsHash.hashCode;
}
