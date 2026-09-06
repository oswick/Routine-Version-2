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

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  _MainHomeScreenState createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  // Estados para la autenticación biométrica
  bool _isCheckingAuth = false;
  bool _isAuthenticated = false;
  bool _authenticationRequired = false;

  @override
  void initState() {
    super.initState();
    print('🏠 NavScreen: initState called');
    WidgetsBinding.instance.addObserver(this);

    // Verificar autenticación al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBiometricAuth();
    });
  }

  @override
  void dispose() {
    print('🏠 NavScreen: dispose called');
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('🏠 NavScreen: App lifecycle changed to $state');

    if (state == AppLifecycleState.resumed) {
      // Cuando la app vuelve del background, verificar auth
      _onAppResumed();
    } else if (state == AppLifecycleState.paused) {
      // Cuando la app va a background, notificar al provider
      _onAppPaused();
    }
  }

  Future<void> _onAppResumed() async {
    print('🏠 NavScreen: ===============================================');
    print('🏠 NavScreen: APP RESUMED - CHECKING AUTHENTICATION');
    print('🏠 NavScreen: ===============================================');

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Usar el nuevo método que verifica si necesita auth
    bool needsAuth = await authProvider.checkAuthOnResume();

    if (needsAuth) {
      print('🏠 NavScreen: 🔒 SHOWING AUTH SCREEN - Authentication required');
      setState(() {
        _isAuthenticated = false;
        _authenticationRequired = true;
        _isCheckingAuth = false;
      });
    } else {
      print('🏠 NavScreen: ✅ CONTINUING TO APP - No authentication required');
      setState(() {
        _isAuthenticated = true;
        _authenticationRequired = false;
        _isCheckingAuth = false;
      });
    }

    print('🏠 NavScreen: Current UI state:');
    print('  - _isAuthenticated: $_isAuthenticated');
    print('  - _authenticationRequired: $_authenticationRequired');
    print('  - _isCheckingAuth: $_isCheckingAuth');
    print('🏠 NavScreen: ===============================================');
  }

  Future<void> _onAppPaused() async {
    print('🏠 NavScreen: ===============================================');
    print('🏠 NavScreen: APP PAUSED - NOTIFYING AUTH PROVIDER');
    print('🏠 NavScreen: ===============================================');

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.onAppPaused();

    print('🏠 NavScreen: App pause notification sent to AuthProvider');
    print('🏠 NavScreen: ===============================================');
  }

  Future<void> _checkBiometricAuth() async {
    if (!mounted) return;

    print('🏠 NavScreen: Checking biometric auth...');

    setState(() {
      _isCheckingAuth = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Debug info
      await authProvider.printDebugInfo();

      // Si la biometría no está habilitada, permitir acceso directo
      if (!authProvider.isBiometricAuthEnabled) {
        print('🏠 NavScreen: Biometric not enabled, allowing access');
        setState(() {
          _isAuthenticated = true;
          _authenticationRequired = false;
          _isCheckingAuth = false;
        });
        return;
      }

      print('🏠 NavScreen: Biometric is enabled, checking if auth needed');

      // Usar el nuevo método que verifica correctamente el tiempo
      bool needsAuth = await authProvider.checkAuthOnResume();

      print('🏠 NavScreen: Needs auth = $needsAuth');

      if (needsAuth) {
        setState(() {
          _authenticationRequired = true;
          _isAuthenticated = false;
          _isCheckingAuth = false;
        });
      } else {
        print('🏠 NavScreen: No auth needed, allowing access');
        setState(() {
          _isAuthenticated = true;
          _authenticationRequired = false;
          _isCheckingAuth = false;
        });
      }
    } catch (e) {
      print('🏠 NavScreen: Error checking auth: $e');
      setState(() {
        _authenticationRequired = true;
        _isAuthenticated = false;
        _isCheckingAuth = false;
      });
    }
  }

  Future<void> _performBiometricAuth() async {
    print('🏠 NavScreen: Performing biometric authentication...');

    setState(() {
      _isCheckingAuth = true;
    });

    try {
      // Intentar autenticación biométrica
      AuthResult authResult = await BiometricService.authenticateWithResult();

      print('🏠 NavScreen: Biometric auth result = ${authResult.success}');

      if (authResult.success) {
        print('🏠 NavScreen: Authentication successful');
        // Autenticación exitosa
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.setLastAuthTime();

        setState(() {
          _isAuthenticated = true;
          _authenticationRequired = false;
          _isCheckingAuth = false;
        });
      } else {
        print(
          '🏠 NavScreen: Authentication failed: ${authResult.errorMessage}',
        );
        setState(() {
          _isCheckingAuth = false;
        });

          if (mounted) {
          M3ESnackbar.show(
            context,
            message:
                authResult.errorMessage ??
                AppLocalizations.of(context).authenticationFailed,
            duration: const Duration(seconds: 4),
          );
        }
      }
    } catch (e) {
      print('🏠 NavScreen: Exception in authentication: $e');
      setState(() {
        _isCheckingAuth = false;
      });

         if (mounted) {
        M3ESnackbar.show(
          context,
          message: ' ${e.toString()}',
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  // Construir la pantalla de autenticación requerida
  Widget _buildAuthRequiredScreen() {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isCheckingAuth) ...[
              // DESPUÉS
              const M3ELoadingIndicator(),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(
                  context,
                ).authenticating, // 'Authenticating...' / 'Autenticando...'
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
                AppLocalizations.of(
                  context,
                ).authenticationRequired, // 'Authentication Required' / 'Autenticación Requerida'
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(
                  context,
                ).authenticateToAccess, // 'Please authenticate to access the app' / 'Autentícate para acceder a la aplicación'
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
                ), // Solo "Authenticate" / "Autentícate"
                style: M3EButtonStyle.filled,
                size: M3EButtonSize.md,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Construir la pantalla principal con navegación
  Widget _buildMainScreen() {
    return Consumer<EventProvider>(
      builder: (context, eventProvider, child) {
        final List<Widget> widgetOptions = [
          const HomeScreen(),
          MonthlyCalendarScreen(
            fromHomeScreen: true,
            events: eventProvider.events,
            onAddEvent: (Event event) => eventProvider.addEvent(event),
            onUpdateEvent: (int index, Event event) {
              // Usar index para localizar el evento y actualizarlo
              final events = eventProvider.events;
              if (index >= 0 && index < events.length) {
                eventProvider.updateEvent(event);
              }
            },
            onDeleteEvent: (int index, bool deleteAll) async {
              final events = eventProvider.events;
              if (index >= 0 && index < events.length) {
                final event = events[index];
                await eventProvider.deleteEvent(event.id, deleteAll: deleteAll);
              }
            },
          ),
          const ProfileScreen(),
        ];

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          body: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            children: widgetOptions,
          ),
          // DESPUÉS
          bottomNavigationBar: M3ENavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
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

  @override
  Widget build(BuildContext context) {
    print(
      '🏠 NavScreen: Building - isChecking=$_isCheckingAuth, isAuth=$_isAuthenticated, reqAuth=$_authenticationRequired',
    );

    // Si se está verificando la autenticación o es requerida, mostrar pantalla de auth
    if (_isCheckingAuth || _authenticationRequired) {
      return _buildAuthRequiredScreen();
    }

    // Si está autenticado o no se requiere, mostrar la app principal
    if (_isAuthenticated) {
      return _buildMainScreen();
    }

    // Estado de carga por defecto
      return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: const Center(child: M3ELoadingIndicator()),
    );
  }
}
