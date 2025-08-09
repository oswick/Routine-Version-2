// lib/screens/nav_screen.dart - Versión actualizada con Provider
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/event_provider.dart';
import 'package:myapp/screens/calendar_screen.dart';
import 'package:myapp/screens/home_screen.dart';
import 'package:myapp/screens/profile_screen.dart';

class MainHomeScreen extends StatefulWidget {
  @override
  _MainHomeScreenState createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EventProvider>(
      builder: (context, eventProvider, child) {
        final List<Widget> widgetOptions = [
          HomeScreen(),
          MonthlyCalendarScreen(
            fromHomeScreen: true,
            events: [],
            onAddEvent: (event) {},
            onUpdateEvent: (int, event) {},
            onDeleteEvent: (int, bool) {},
          ),
          ProfileScreen(), //pantalla de perfil
        ];

        return Scaffold(
          body: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            children: widgetOptions,
          ),
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
                labelBehavior:
                    NavigationDestinationLabelBehavior.onlyShowSelected,
                destinations: [
                  NavigationDestination(
                    icon: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            _selectedIndex == 0
                                ? Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.1)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        _selectedIndex == 0
                            ? Icons.home_rounded
                            : Icons.home_outlined,
                        color:
                            _selectedIndex == 0
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
                        color:
                            _selectedIndex == 1
                                ? Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.1)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        _selectedIndex == 1
                            ? Icons.calendar_month_rounded
                            : Icons.calendar_month_outlined,
                        color:
                            _selectedIndex == 1
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
                        color:
                            _selectedIndex == 2
                                ? Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.1)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        _selectedIndex == 2
                            ? Icons.person
                            : Icons.person_outline,
                        color:
                            _selectedIndex == 2
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
                        Icons.person,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
}
