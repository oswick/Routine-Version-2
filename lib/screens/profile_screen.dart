import 'package:flutter/material.dart';
import 'package:myapp/services/auth_service.dart';
import 'package:myapp/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event.dart';
import '../widgets/connectivity_indicator.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final SyncService _syncService = SyncService();
  List<Event> _events = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    if (_authService.isAuthenticated) {
      final events = await _syncService.getEvents();
      setState(() {
        _events = events;
      });
    }
  }

  Future<void> _handleAuthAction() async {
    setState(() => _isLoading = true);

    try {
      if (_authService.isAuthenticated) {
        await _authService.signOut();
        setState(() => _events = []);
      } else {
        await _authService.signInWithGoogle();
        await _loadEvents();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showSignOutDialog() async {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleAuthAction();
              },
              child: Text(
                'Sign Out',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        );
      },
    );
  }

  // Función para verificar si un evento repetitivo está completo para hoy
  Future<bool> _isRepetitiveEventCompletedToday(Event event) async {
    if (event.repeatDays.isEmpty) {
      return event.isCompleted;
    }

    final now = DateTime.now();
    final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final completionKey = 'event_${event.id}_completion_$dateKey';
    
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(completionKey) ?? false;
  }

  // Función para verificar si un evento es para hoy
  bool _isEventForToday(Event event) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    if (event.repeatDays.isNotEmpty) {
      // Para eventos repetitivos, verificar si hoy es uno de los días
      return event.repeatDays.contains(now.weekday);
    } else {
      // Para eventos únicos, verificar si es el mismo día
      final eventDate = DateTime(
        event.startTime.year,
        event.startTime.month,
        event.startTime.day,
      );
      return eventDate.isAtSameMomentAs(today);
    }
  }

  Future<Map<String, int>> _getEventStatistics() async {
    int total = _events.length;
    int completed = 0;
    int todayPending = 0;
    int totalIncompleted = 0;

    // Calcular eventos completados y incompletos
    for (var event in _events) {
      bool isCompleted = await _isRepetitiveEventCompletedToday(event);
      
      if (isCompleted) {
        completed++;
      } else {
        totalIncompleted++;
      }

      // Para eventos del día de hoy que no están completados
      if (_isEventForToday(event) && !isCompleted) {
        todayPending++;
      }
    }

    // Contar categorías
    Map<String, int> categories = {};
    for (var event in _events) {
      categories[event.category] = (categories[event.category] ?? 0) + 1;
    }

    return {
      'total': total,
      'completed': completed,
      'todayPending': todayPending,
      'totalIncompleted': totalIncompleted,
      ...categories,
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        elevation: 0,
        title: Row(
          children: [
            const SizedBox(width: 12),
            Text(
              'Profile',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _isLoading
                ? SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                : IconButton(
                    icon: Icon(
                      user != null ? Icons.logout_rounded : Icons.login_rounded,
                      color: user != null
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: user != null ? _showSignOutDialog : _handleAuthAction,
                    tooltip: user != null ? 'Sign out' : 'Sign in with Google',
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (user != null) ...[
                _buildUserCard(user),
                const SizedBox(height: 24),
                if (_events.isNotEmpty) _buildStatisticsSection(),
              ] else ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'Sign in to view your profile and statistics',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(dynamic user) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: user.userMetadata?['avatar_url'] != null
                  ? NetworkImage(user.userMetadata!['avatar_url'])
                  : null,
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              child: user.userMetadata?['avatar_url'] == null
                  ? Text(
                      user.userMetadata?['full_name']
                              ?.toString()
                              .substring(0, 1)
                              .toUpperCase() ??
                          user.email?.substring(0, 1).toUpperCase() ??
                          'U',
                      style: TextStyle(
                        fontSize: 24,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.userMetadata?['full_name'] ?? 'User',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statistics',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<Map<String, int>>(
          future: _getEventStatistics(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final stats = snapshot.data!;
            
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard(
                  'Total Tasks',
                  stats['total'] ?? 0,
                  Icons.list_alt,
                  Theme.of(context).colorScheme.primary,
                ),
                _buildStatCard(
                  'Completed',
                  stats['completed'] ?? 0,
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildStatCard(
                  'Today Pending',
                  stats['todayPending'] ?? 0,
                  Icons.today,
                  Colors.orange,
                ),
                _buildStatCard(
                  'Incompleted',
                  stats['totalIncompleted'] ?? 0,
                  Icons.pending_actions,
                  Colors.red,
                ),
                _buildStatCard(
                  'Success Rate',
                  stats['total'] != 0
                      ? ((stats['completed'] ?? 0) * 100 ~/ stats['total']!)
                      : 0,
                  Icons.auto_graph,
                  Colors.blue,
                  isPercentage: true,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    int value,
    IconData icon,
    Color color, {
    bool isPercentage = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isPercentage ? '$value%' : value.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}