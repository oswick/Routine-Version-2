// lib/screens/nav_screen.dart
import 'package:material_3_expressive/components/buttons/enums/m3e_button_enums.dart';
import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/components/navigation_bar/models/m3e_navigation_bar_destination.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/event.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/event_provider.dart';
import 'package:myapp/providers/auth_provider.dart';
import 'package:myapp/services/biometric_service.dart';
import 'package:myapp/screens/calendar_screen.dart';
import 'package:myapp/screens/home_screen.dart';
import 'package:myapp/screens/profile_screen.dart';
import 'package:myapp/features/focus/providers/focus_provider.dart';
import 'package:myapp/features/focus/screens/focus_screen.dart';

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  _MainHomeScreenState createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  bool _isCheckingAuth = false;
  bool _isAuthenticated = false;
  bool _authenticationRequired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkBiometricAuth());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    } else if (state == AppLifecycleState.paused) {
      _onAppPaused();
    }
  }

  Future<void> _onAppResumed() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final needsAuth = await authProvider.checkAuthOnResume();
    if (!mounted) return;
    setState(() {
      _isAuthenticated = !needsAuth;
      _authenticationRequired = needsAuth;
      _isCheckingAuth = false;
    });
  }

  Future<void> _onAppPaused() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.onAppPaused();
  }

  Future<void> _checkBiometricAuth() async {
    if (!mounted) return;
    setState(() => _isCheckingAuth = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.printDebugInfo();
      if (!authProvider.isBiometricAuthEnabled) {
        if (!mounted) return;
        setState(() {
          _isAuthenticated = true;
          _authenticationRequired = false;
          _isCheckingAuth = false;
        });
        return;
      }
      final needsAuth = await authProvider.checkAuthOnResume();
      if (!mounted) return;
      setState(() {
        _authenticationRequired = needsAuth;
        _isAuthenticated = !needsAuth;
        _isCheckingAuth = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _authenticationRequired = true;
        _isAuthenticated = false;
        _isCheckingAuth = false;
      });
    }
  }

  Future<void> _performBiometricAuth() async {
    if (!mounted) return;
    setState(() => _isCheckingAuth = true);
    try {
      final result = await BiometricService.authenticateWithResult();
      if (!mounted) return;
      if (result.success) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.setLastAuthTime();
        if (!mounted) return;
        setState(() {
          _isAuthenticated = true;
          _authenticationRequired = false;
          _isCheckingAuth = false;
        });
      } else {
        setState(() => _isCheckingAuth = false);
        M3ESnackbar.show(
          context,
          message: result.errorMessage ?? AppLocalizations.of(context).authenticationFailed,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCheckingAuth = false);
      M3ESnackbar.show(context, message: e.toString(), duration: const Duration(seconds: 4));
    }
  }

  Widget _buildAuthRequiredScreen() {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: _isCheckingAuth
            ? const M3ELoadingIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 64, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(AppLocalizations.of(context).authenticationRequired,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(AppLocalizations.of(context).authenticateToAccess, textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  M3EButton.icon(
                    onPressed: _performBiometricAuth,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Authenticate'),
                    style: M3EButtonStyle.filled,
                    size: M3EButtonSize.md,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildMainScreen() {
    return Consumer<EventProvider>(
      builder: (context, eventProvider, child) {
        final widgetOptions = [
          const HomeScreen(),
          MonthlyCalendarScreen(
            fromHomeScreen: true,
            events: eventProvider.events,
            onAddEvent: eventProvider.addEvent,
            onUpdateEvent: (index, event) {
              final events = eventProvider.events;
              if (index >= 0 && index < events.length) eventProvider.updateEvent(event);
            },
            onDeleteEvent: (index, deleteAll) async {
              final events = eventProvider.events;
              if (index >= 0 && index < events.length) {
                await eventProvider.deleteEvent(events[index].id, deleteAll: deleteAll);
              }
            },
          ),
          const FocusScreen(),
          const ProfileScreen(),
        ];

        return ChangeNotifierProvider(
          create: (_) => FocusProvider(),
          child: Builder(
            builder: (context) => Scaffold(
              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
              body: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _selectedIndex = index),
                children: widgetOptions,
              ),
              bottomNavigationBar: M3ENavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: _onItemTapped,
                backgroundColor: Theme.of(context).colorScheme.surface,
                destinations: [
                  M3ENavigationBarDestination(icon: const Icon(Icons.home_outlined), label: AppLocalizations.of(context).home),
                  M3ENavigationBarDestination(icon: const Icon(Icons.calendar_month_outlined), label: AppLocalizations.of(context).calendar),
                  const M3ENavigationBarDestination(icon: Icon(Icons.timer_outlined), label: 'Focus'),
                  M3ENavigationBarDestination(icon: const Icon(Icons.person_outline), label: AppLocalizations.of(context).profile),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth || _authenticationRequired) return _buildAuthRequiredScreen();
    if (_isAuthenticated) return _buildMainScreen();
    return const Scaffold(body: Center(child: M3ELoadingIndicator()));
  }
}
