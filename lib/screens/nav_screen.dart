// lib/screens/nav_screen.dart
import 'package:material_3_expressive/components/buttons/enums/m3e_button_enums.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/providers/auth_provider.dart';
import 'package:myapp/screens/minimal_routine_screen.dart';
import 'package:myapp/services/biometric_service.dart';
import 'package:provider/provider.dart';

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen>
    with WidgetsBindingObserver {
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
    if (!mounted) return;
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
        _isAuthenticated = !needsAuth;
        _authenticationRequired = needsAuth;
        _isCheckingAuth = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAuthenticated = false;
        _authenticationRequired = true;
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
          message: result.errorMessage ??
              AppLocalizations.of(context).authenticationFailed,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCheckingAuth = false);
      M3ESnackbar.show(
        context,
        message: e.toString(),
        duration: const Duration(seconds: 4),
      );
    }
  }

  Widget _buildAuthRequiredScreen() {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isCheckingAuth) ...[
                const M3ELoadingIndicator(),
                const SizedBox(height: 16),
                Text(l10n.authenticating),
              ] else ...[
                Icon(Icons.lock_outline, size: 48, color: scheme.primary),
                const SizedBox(height: 20),
                Text(
                  l10n.authenticationRequired,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.authenticateToAccess,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                M3EButton.icon(
                  onPressed: _performBiometricAuth,
                  icon: const Icon(Icons.fingerprint),
                  label: Text(l10n.authenticateToAccess.replaceAll(
                    ' to access the app',
                    '',
                  )),
                  style: M3EButtonStyle.filled,
                  size: M3EButtonSize.md,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth || _authenticationRequired) {
      return _buildAuthRequiredScreen();
    }

    if (_isAuthenticated) {
      return const MinimalRoutineScreen();
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: const Center(child: M3ELoadingIndicator()),
    );
  }
}
