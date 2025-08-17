// lib/screens/nav_screen.dart
import 'package:flutter/material.dart';
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

class _MainHomeScreenState extends State<MainHomeScreen> with WidgetsBindingObserver {
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
        print('🏠 NavScreen: Authentication failed: ${authResult.errorMessage}');
        setState(() {
          _isCheckingAuth = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authResult.errorMessage ?? 'Authentication failed'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      print('🏠 NavScreen: Exception in authentication: $e');
      setState(() {
        _isCheckingAuth = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
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
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Authenticating...',
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.7),
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
                'Authentication Required',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please authenticate to access the app',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _performBiometricAuth,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Authenticate'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  textStyle: const TextStyle(fontSize: 18),
                ),
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
            onAddEvent: (Event event) {
              eventProvider.addEvent(event);
            },
            onUpdateEvent: (int index, Event event) {
              eventProvider.updateEvent(event);
            },
            onDeleteEvent: (int index, bool deleteAll) {
              eventProvider.deleteEvent(deleteAll as String);
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
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(),
              child: NavigationBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                indicatorColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
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
                        _selectedIndex == 0 ? Icons.home_rounded : Icons.home_outlined,
                        color: _selectedIndex == 0
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
                            ? Icons.calendar_month_rounded
                            : Icons.calendar_month_outlined,
                        color: _selectedIndex == 1
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
                        color: _selectedIndex == 2
                            ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        _selectedIndex == 2 ? Icons.person : Icons.person_outline,
                        color: _selectedIndex == 2
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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

  @override
  Widget build(BuildContext context) {
    print('🏠 NavScreen: Building - isChecking=$_isCheckingAuth, isAuth=$_isAuthenticated, reqAuth=$_authenticationRequired');
    
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
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}