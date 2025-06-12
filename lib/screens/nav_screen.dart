import 'package:flutter/material.dart';
import 'package:myapp/models/event.dart';
import 'package:myapp/screens/calendar_screen.dart';
import 'package:myapp/screens/home_screen.dart';
import 'package:myapp/screens/pomodoro_screen.dart';
import 'package:myapp/screens/statistics_screen.dart';
import 'package:myapp/services/sync_service.dart';
import 'package:myapp/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  _MainHomeScreenState createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _selectedIndex = 0;

  // Servicios centralizados
  final SyncService _syncService = SyncService();
  final AuthService _authService = AuthService();

  // Lista de eventos centralizada
  List<Event> _events = [];

  @override
  void initState() {
    super.initState();
    _initializeServices();

    // Escuchar cambios de autenticación
    _authService.authStateChanges.listen((state) {
      if (state.event == AuthChangeEvent.signedIn) {
        _loadEvents();
      }
    });
  }

  Future<void> _initializeServices() async {
    await _syncService.init();
    await _loadEvents();
  }

  Future<void> _loadEvents() async {
    final events = await _syncService.getEvents();
    setState(() {
      _events = events;
    });
  }

  // Función para agregar eventos
  void _onAddEvent(Event event) async {
    final userId = _authService.currentUserId;
    if (userId == null) return;

    final newEvent = event.copyWith(userId: userId);
    await _syncService.saveEvent(newEvent);
    await _loadEvents(); // Recargar desde la base de datos
  }

  // Función para actualizar eventos
  void _onUpdateEvent(int index, Event updatedEvent) async {
    await _syncService.saveEvent(updatedEvent);
    await _loadEvents(); // Recargar desde la base de datos
  }

  // Función para eliminar eventos
  void _onDeleteEvent(int index, bool deleteAll) async {
    if (index >= 0 && index < _events.length) {
      final event = _events[index];

      if (deleteAll) {
        await _syncService.deleteAllEventInstances(event.id);
      } else {
        await _syncService.deleteEvent(event.id);
      }

      await _loadEvents(); // Recargar desde la base de datos
    }
  }

  @override
  Widget build(BuildContext context) {
    // Crear la lista de widgets con los eventos actualizados
    final List<Widget> widgetOptions = [
      HomeScreen(
        // Pasar los eventos y funciones al HomeScreen
        events: _events,
        onAddEvent: _onAddEvent,
        onUpdateEvent: _onUpdateEvent,
        onDeleteEvent: _onDeleteEvent,
        onEventsUpdated: _loadEvents, // Callback para recargar eventos
      ),
      PomodoroScreen(
        event: Event(
          id: 'temp-id',
          title: 'Focus Time',
          description: 'Pomodoro Session',
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(minutes: 25)),
          repeatDays: [],
          importance: 3,
          category: 'productivity',
          userId: 'local-user',
        ),
      ),
      MonthlyCalendarScreen(
        events: _events,
        onAddEvent: _onAddEvent,
        onUpdateEvent: _onUpdateEvent,
        onDeleteEvent: _onDeleteEvent,
        fromHomeScreen: true,
      ),
      StatisticsScreen(),
    ];

    return Scaffold(
      body: widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            indicatorColor: Theme.of(
              context,
            ).colorScheme.primary.withOpacity(0.12),
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            destinations: [
              NavigationDestination(
                icon: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _selectedIndex == 0
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _selectedIndex == 0
                        ? Icons.home_rounded
                        : Icons.home_outlined,
                    color: _selectedIndex == 0
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                    size: 24,
                  ),
                ),
                selectedIcon: Container(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.home_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _selectedIndex == 1
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _selectedIndex == 1
                        ? Icons.timer_rounded
                        : Icons.timer_outlined,
                    color: _selectedIndex == 1
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                    size: 24,
                  ),
                ),
                selectedIcon: Container(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.timer_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),
                label: 'Focus',
              ),
              NavigationDestination(
                icon: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _selectedIndex == 2
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _selectedIndex == 2
                        ? Icons.calendar_month_rounded
                        : Icons.calendar_month_outlined,
                    color: _selectedIndex == 2
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                    size: 24,
                  ),
                ),
                selectedIcon: Container(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),
                label: 'Calendar',
              ),
              NavigationDestination(
                icon: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _selectedIndex == 3
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _selectedIndex == 3
                        ? Icons.analytics
                        : Icons.analytics_outlined,
                    color: _selectedIndex == 3
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                    size: 24,
                  ),
                ),
                label: 'Stats',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
}
