import 'package:flutter/material.dart';
import 'package:myapp/services/auth_service.dart';
import 'package:myapp/services/sync_service.dart';
import '../models/event.dart';

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
    setState(() {
      _isLoading = true;
    });

    try {
      if (_authService.isAuthenticated) {
        await _authService.signOut();
        setState(() {
          _events = [];
        });
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
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

    Future<void> _showSignOutDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleAuthAction();
              },
              child: Text(
                'Sign Out',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Map<String, int> _getEventStatistics() {
    int totalEvents = _events.length;
    int completedEvents = _events.where((event) => event.isCompleted).length;
    int pendingEvents = totalEvents - completedEvents;
    
    Map<String, int> categoryCount = {};
    for (var event in _events) {
      categoryCount[event.category] = (categoryCount[event.category] ?? 0) + 1;
    }

    return {
      'total': totalEvents,
      'completed': completedEvents,
      'pending': pendingEvents,
      ...categoryCount,
    };
  }

 @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final stats = _getEventStatistics();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        elevation: 0,
        title: Text(
          'Profile',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (user != null) // Solo mostrar el botón si hay un usuario autenticado
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
                        Icons.logout_rounded,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: _showSignOutDialog,
                      tooltip: 'Sign out',
                    ),
            ),
          if (user == null) // Mostrar botón de inicio de sesión si no hay usuario
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
                        Icons.login_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onPressed: _handleAuthAction,
                      tooltip: 'Sign in with Google',
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
                // User info card
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
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
                                  user.userMetadata?['full_name']?.toString().substring(0, 1).toUpperCase() ??
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
                ),
                const SizedBox(height: 24),
                // Statistics Section
                if (_events.isNotEmpty) ...[
                  Text(
                    'Statistics',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
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
                        'Pending',
                        stats['pending'] ?? 0,
                        Icons.pending_actions,
                        Colors.orange,
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
                  ),
                ],
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

  Widget _buildStatCard(String title, int value, IconData icon, Color color,
      {bool isPercentage = false}) {
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
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
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