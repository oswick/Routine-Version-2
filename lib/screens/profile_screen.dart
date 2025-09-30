import 'package:flutter/material.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/screens/settings_screen.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/event_provider.dart';
import 'package:myapp/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event.dart';

// Clase para manejar el estado del tema
class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode;

  ThemeProvider({ThemeMode themeMode = ThemeMode.system})
    : _themeMode = themeMode;

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode themeMode) {
    _themeMode = themeMode;
    notifyListeners();
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  Future<void> _handleAuthAction() async {
    setState(() => _isLoading = true);
    try {
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      if (_authService.isAuthenticated) {
        await _authService.signOut();
      } else {
        await _authService.signInWithGoogle();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          eventProvider.loadEvents();
        });
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
          title: Text(AppLocalizations.of(context).signOut),
          content: Text(AppLocalizations.of(context).areYouSureSignOut),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                AppLocalizations.of(context).cancel,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleAuthAction();
              },
              child: Text(
                AppLocalizations.of(context).signOut,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _isRepetitiveEventCompletedToday(Event event) async {
    if (event.repeatDays.isEmpty) {
      return event.isCompleted;
    }
    final now = DateTime.now();
    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final completionKey = 'event_${event.id}_completion_$dateKey';
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(completionKey) ?? false;
  }

  bool _isEventForToday(Event event) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (event.repeatDays.isNotEmpty) {
      return event.repeatDays.contains(now.weekday);
    } else {
      final eventDate = DateTime(
        event.startTime.year,
        event.startTime.month,
        event.startTime.day,
      );
      return eventDate.isAtSameMomentAs(today);
    }
  }

  Future<Map<String, int>> _getEventStatistics(List<Event> events) async {
    int total = events.length;
    int completed = 0;
    int todayPending = 0;
    int totalIncompleted = 0;

    for (var event in events) {
      bool isCompleted = await _isRepetitiveEventCompletedToday(event);
      if (isCompleted) {
        completed++;
      } else {
        totalIncompleted++;
      }
      if (_isEventForToday(event) && !isCompleted) {
        todayPending++;
      }
    }

    Map<String, int> categories = {};
    for (var event in events) {
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
    return Consumer<EventProvider>(
      builder: (context, eventProvider, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            title: Row(
              children: [
                const SizedBox(width: 12),
                Text(
                  AppLocalizations.of(context).profile,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'settings') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SettingsScreen()),
                    );
                  } else if (value == 'signout') {
                    _showSignOutDialog();
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'settings',
                    child: ListTile(
                      leading: Icon(Icons.settings),
                      title: Text(AppLocalizations.of(context).settings),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'signout',
                    child: ListTile(
                      leading: Icon(Icons.logout),
                      title: Text(AppLocalizations.of(context).signOut),
                    ),
                  ),
                ],
              ),
           
            ],
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () => eventProvider.loadEvents(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (user != null) ...[
                      _buildUserCard(user),
                      const SizedBox(height: 24),
                      if (eventProvider.isLoading &&
                          eventProvider.events.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (eventProvider.events.isNotEmpty)
                        _buildStatisticsSection(eventProvider.events)
                      else
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.event_note,
                                  size: 64,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.3),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  AppLocalizations.of(context).noEventsYet,
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  AppLocalizations.of(context).startByCreatingFirstEvent,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ] else ...[
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 64,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                AppLocalizations.of(
                                  context,
                                ).signInToViewProfile,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),

                              Text(
                                AppLocalizations.of(
                                  context,
                                ).accessStatisticsAndSync,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.4),
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _isLoading
                                    ? null
                                    : _handleAuthAction,
                                icon: const Icon(Icons.login),
                                label: Text(
                                  AppLocalizations.of(context).signInWithGoogle,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
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

  Widget _buildStatisticsSection(List<Event> events) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocalizations.of(context).statistics,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),

            Text(
              '${events.length} ${AppLocalizations.of(context).events}',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FutureBuilder<Map<String, int>>(
          future: _getEventStatistics(events),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(),
                ),
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
                  AppLocalizations.of(context).totalTasks,
                  stats['total'] ?? 0,
                  Icons.list_alt,
                  Theme.of(context).colorScheme.primary,
                ),
                _buildStatCard(
                  AppLocalizations.of(context).completed,
                  stats['completed'] ?? 0,
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildStatCard(
                  AppLocalizations.of(context).todayPending,
                  stats['todayPending'] ?? 0,
                  Icons.today,
                  Colors.orange,
                ),
                _buildStatCard(
                  AppLocalizations.of(context).incompleted,
                  stats['totalIncompleted'] ?? 0,
                  Icons.pending_actions,
                  Colors.red,
                ),
                _buildStatCard(
                  AppLocalizations.of(context).successRate,
                  stats['total'] != 0
                      ? ((stats['completed'] ?? 0) * 100 ~/ stats['total']!)
                      : 0,
                  Icons.auto_graph,
                  Colors.blue,
                  isPercentage: true,
                ),
                _buildStatCard(
                  AppLocalizations.of(context).categories,
                  _getMostPopularCategoryCount(stats),
                  Icons.category,
                  Colors.purple,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  int _getMostPopularCategoryCount(Map<String, int> stats) {
    final categories = [
      AppLocalizations.of(context).school,
      AppLocalizations.of(context).home,
      AppLocalizations.of(context).work,
      AppLocalizations.of(context).shopping,
      AppLocalizations.of(context).health,
      AppLocalizations.of(context).health,
    ];
    int maxCount = 0;
    for (String category in categories) {
      final count = stats[category] ?? 0;
      if (count > maxCount) {
        maxCount = count;
      }
    }
    return maxCount;
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
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
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
