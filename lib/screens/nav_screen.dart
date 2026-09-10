// lib/screens/nav_screen.dart
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
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

/// Root screen of the app once the user is inside it.
/// Handles:
///  - Bottom navigation between Home / Calendar / Profile.
///  - Biometric re-authentication when the app is backgrounded and resumed.
class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  _MainHomeScreenState createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen>
    with WidgetsBindingObserver {
  // Index of the currently selected bottom nav tab.
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  // --- Biometric auth state ---
  bool _isCheckingAuth =
      false; // true while we're verifying/awaiting biometrics
  bool _isAuthenticated = false; // true once the user has passed auth
  bool _authenticationRequired = false; // true when the lock screen must show

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Check biometric auth status right after the first frame is drawn.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBiometricAuth();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  /// Reacts to the app going to background/foreground so we can
  /// lock/unlock the screen with biometrics as needed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    } else if (state == AppLifecycleState.paused) {
      _onAppPaused();
    }
  }

  /// Called when the app comes back to the foreground.
  /// Asks AuthProvider whether re-authentication is needed (e.g. enough
  /// time has passed since the app was paused) and updates UI state.
  Future<void> _onAppResumed() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    bool needsAuth = await authProvider.checkAuthOnResume();

    if (!mounted) return;

    setState(() {
      _isAuthenticated = !needsAuth;
      _authenticationRequired = needsAuth;
      _isCheckingAuth = false;
    });
  }

  /// Called when the app goes to background.
  /// Lets AuthProvider record the pause time so it can decide later
  /// whether re-authentication is required.
  Future<void> _onAppPaused() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.onAppPaused();
  }

  /// Initial auth check performed on screen load.
  /// Skips the lock screen entirely if biometric auth isn't enabled.
  Future<void> _checkBiometricAuth() async {
    if (!mounted) return;

    setState(() {
      _isCheckingAuth = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Biometric auth disabled by the user -> go straight into the app.
      if (!authProvider.isBiometricAuthEnabled) {
        setState(() {
          _isAuthenticated = true;
          _authenticationRequired = false;
          _isCheckingAuth = false;
        });
        return;
      }

      bool needsAuth = await authProvider.checkAuthOnResume();

      setState(() {
        _authenticationRequired = needsAuth;
        _isAuthenticated = !needsAuth;
        _isCheckingAuth = false;
      });
    } catch (e) {
      // On any failure, default to requiring auth (fail closed).
      setState(() {
        _authenticationRequired = true;
        _isAuthenticated = false;
        _isCheckingAuth = false;
      });
    }
  }

  /// Triggers the platform biometric prompt and updates UI state
  /// based on the result.
  Future<void> _performBiometricAuth() async {
    HapticFeedback.mediumImpact(); // confirms the auth attempt was triggered

    setState(() {
      _isCheckingAuth = true;
    });

    try {
      AuthResult authResult = await BiometricService.authenticateWithResult();

      if (authResult.success) {
        HapticFeedback.lightImpact(); // success feedback

        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.setLastAuthTime();

        if (!mounted) return;
        setState(() {
          _isAuthenticated = true;
          _authenticationRequired = false;
          _isCheckingAuth = false;
        });
      } else {
        HapticFeedback.vibrate(); // failure feedback

        if (!mounted) return;
        setState(() {
          _isCheckingAuth = false;
        });

        M3ESnackbar.show(
          context,
          message:
              authResult.errorMessage ??
              AppLocalizations.of(context).authenticationFailed,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      HapticFeedback.vibrate(); // error feedback

      if (!mounted) return;
      setState(() {
        _isCheckingAuth = false;
      });

      M3ESnackbar.show(
        context,
        message: ' ${e.toString()}',
        duration: const Duration(seconds: 4),
      );
    }
  }

  /// Lock screen shown while checking auth status or when
  /// re-authentication is required.
  Widget _buildAuthRequiredScreen() {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isCheckingAuth) ...[
              const M3ELoadingIndicator(),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).authenticating,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
            ] else ...[
              Icon(
                Icons.lock_outline,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).authenticationRequired,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).authenticateToAccess,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 32),
              M3EButton.icon(
                onPressed: _performBiometricAuth,
                icon: const Icon(Icons.fingerprint),
                label: Text(
                  AppLocalizations.of(
                    context,
                  ).authenticateToAccess.replaceAll(' to access the app', ''),
                ),
                style: M3EButtonStyle.filled,
                size: M3EButtonSize.md,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Main app UI: PageView with Home / Calendar / Profile and the
  /// bottom navigation bar that drives it.
  Widget _buildMainScreen() {
    return Consumer<EventProvider>(
      builder: (context, eventProvider, child) {
        final List<Widget> widgetOptions = [
          const HomeScreen(),
          const MonthlyCalendarScreen(fromHomeScreen: true),
          const ProfileScreen(),
        ];

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          body: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              // Keeps the nav bar in sync when the user swipes between pages
              // instead of tapping a destination.
              setState(() {
                _selectedIndex = index;
              });
            },
            children: widgetOptions,
          ),
          bottomNavigationBar: M3ENavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
            backgroundColor: Theme.of(context).colorScheme.surface,
            destinations: [
              M3ENavigationBarDestination(
                icon: const Icon(Icons.home_outlined),
                label: AppLocalizations.of(context).home,
              ),
              M3ENavigationBarDestination(
                icon: const Icon(Icons.calendar_month_outlined),
                label: AppLocalizations.of(context).calendar,
              ),
              M3ENavigationBarDestination(
                icon: const Icon(Icons.person_outline),
                label: AppLocalizations.of(context).profile,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Handles bottom nav taps: updates selected index and animates the
  /// PageView to the matching page.
  void _onItemTapped(int index) {
    HapticFeedback.selectionClick(); // tactile confirmation of tab switch

    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Auth check in progress or re-auth required -> show lock screen.
    if (_isCheckingAuth || _authenticationRequired) {
      return _buildAuthRequiredScreen();
    }

    // Authenticated (or auth not required) -> show the main app.
    if (_isAuthenticated) {
      return _buildMainScreen();
    }

    // Fallback loading state (shouldn't normally be reached).
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: const Center(child: M3ELoadingIndicator()),
    );
  }
}
