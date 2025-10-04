// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/auth_provider.dart';
import 'package:myapp/services/biometric_service.dart';
import 'package:myapp/utils/event_sorting_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isBiometricAvailable = false;
  bool _isCheckingBiometric = true;

  // 🆕 Estado de ordenamiento
  EventSortOption _selectedSortOption = EventSortOption.timeAscending;
  bool _isLoadingSortPreference = true;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
    _loadSortPreference();
  }

  // 🆕 Cargar preferencia de ordenamiento
  Future<void> _loadSortPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sortIndex = prefs.getInt('event_sort_option') ?? 0;

      if (mounted) {
        setState(() {
          _selectedSortOption = EventSortOption.values[sortIndex];
          _isLoadingSortPreference = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading sort preference: $e');
      if (mounted) {
        setState(() => _isLoadingSortPreference = false);
      }
    }
  }

  // 🆕 Guardar preferencia de ordenamiento
  Future<void> _saveSortPreference(EventSortOption option) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('event_sort_option', option.index);

      if (mounted) {
        setState(() => _selectedSortOption = option);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sort preference saved: ${_getSortOptionName(option)}',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving sort preference: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving preference: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // 🆕 Obtener nombre de la opción de ordenamiento
  String _getSortOptionName(EventSortOption option) {
    switch (option) {
      case EventSortOption.timeAscending:
        return 'Time (Early → Late)';
      case EventSortOption.timeDescending:
        return 'Time (Late → Early)';
      case EventSortOption.importance:
        return 'Importance';
      case EventSortOption.importanceAndTime:
        return 'Importance + Time';
      case EventSortOption.title:
        return 'Alphabetical';
      case EventSortOption.category:
        return 'Category';
    }
  }

  // 🆕 Obtener descripción de la opción
  String _getSortOptionDescription(EventSortOption option) {
    switch (option) {
      case EventSortOption.timeAscending:
        return 'Events ordered from earliest to latest';
      case EventSortOption.timeDescending:
        return 'Events ordered from latest to earliest';
      case EventSortOption.importance:
        return 'Events ordered by importance level';
      case EventSortOption.importanceAndTime:
        return 'High importance first, then by time';
      case EventSortOption.title:
        return 'Events ordered alphabetically by title';
      case EventSortOption.category:
        return 'Events grouped by category, then by time';
    }
  }

  // 🆕 Mostrar diálogo de opciones de ordenamiento
  Future<void> _showSortOptionsDialog() async {
    final result = await showDialog<EventSortOption>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Event Sorting'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: EventSortOption.values.map((option) {
                return RadioListTile<EventSortOption>(
                  title: Text(_getSortOptionName(option)),
                  subtitle: Text(
                    _getSortOptionDescription(option),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  value: option,
                  groupValue: _selectedSortOption,
                  onChanged: (value) {
                    Navigator.of(context).pop(value);
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context).cancel),
            ),
          ],
        );
      },
    );

    if (result != null && result != _selectedSortOption) {
      await _saveSortPreference(result);
    }
  }

  Future<void> _checkBiometricAvailability() async {
    bool available = await BiometricService.isBiometricAvailable();
    if (mounted) {
      setState(() {
        _isBiometricAvailable = available;
        _isCheckingBiometric = false;
      });
    }
  }

  Future<void> _toggleBiometricAuth(bool value) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (value) {
      AuthResult result = await BiometricService.authenticateWithResult();
      if (result.success) {
        await authProvider.setBiometricAuthEnabled(true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Biometric authentication enabled successfully!',
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? 'Authentication failed.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } else {
      AuthResult result = await BiometricService.authenticateWithResult();
      if (result.success) {
        await authProvider.setBiometricAuthEnabled(false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Biometric authentication disabled.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Authentication required to change this setting. ${result.errorMessage ?? ''}',
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _showTimeoutOptionsDialog(AuthProvider authProvider) async {
    final result = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context).autoLockTimeout),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: AuthProvider.timeoutOptions.map((minutes) {
              return RadioListTile<int>(
                title: Text(AuthProvider.getTimeoutText(minutes)),
                value: minutes,
                groupValue: authProvider.authTimeoutMinutes,
                onChanged: (value) {
                  Navigator.of(context).pop(value);
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context).cancel),
            ),
          ],
        );
      },
    );

    if (result != null && result != authProvider.authTimeoutMinutes) {
      AuthResult authResult = await BiometricService.authenticateWithResult();
      if (authResult.success) {
        await authProvider.setAuthTimeout(result);
        await authProvider.setLastAuthTime();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Auto-lock timeout set to ${AuthProvider.getTimeoutText(result)}',
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Authentication required to change this setting. ${authResult.errorMessage ?? ''}',
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleImmediateTimeout(bool value) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    AuthResult result = await BiometricService.authenticateWithResult();
    if (result.success) {
      await authProvider.setImmediateTimeout(value);
      await authProvider.setLastAuthTime();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? 'Immediate lock enabled - app will lock when sent to background'
                  : 'Immediate lock disabled - timeout will be used instead',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Authentication required to change this setting. ${result.errorMessage ?? ''}',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Widget _buildBiometricSettings(AuthProvider authProvider) {
    if (_isCheckingBiometric) {
      return const ListTile(
        leading: Icon(Icons.fingerprint),
        title: Text('Enable Biometric Authentication'),
        trailing: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Column(
      children: [
        SwitchListTile(
          title: Text(
            AppLocalizations.of(context).enableBiometricAuthentication,
            style: TextStyle(
              color: _isBiometricAvailable
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: !_isBiometricAvailable
              ? Text(
                  AppLocalizations.of(context).biometricNotAvailableDevice,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                )
              : authProvider.isBiometricAuthEnabled
              ? Text(
                  AppLocalizations.of(context).appWillRequireBiometric,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 12,
                  ),
                )
              : null,
          value: authProvider.isBiometricAuthEnabled,
          onChanged: _isBiometricAvailable ? _toggleBiometricAuth : null,
          secondary: Icon(
            Icons.fingerprint,
            color: _isBiometricAvailable
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
        ),

        if (authProvider.isBiometricAuthEnabled && _isBiometricAvailable) ...[
          const Divider(height: 1),

          ListTile(
            leading: Icon(
              Icons.timer,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text(
              'Auto-lock Timeout',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'Currently set to ${AuthProvider.getTimeoutText(authProvider.authTimeoutMinutes)}${authProvider.immediateTimeoutEnabled ? ' (overridden by immediate lock)' : ''}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: authProvider.immediateTimeoutEnabled
                ? null
                : () => _showTimeoutOptionsDialog(authProvider),
            enabled: !authProvider.immediateTimeoutEnabled,
          ),

          const Divider(height: 1),

          SwitchListTile(
            title: const Text(
              'Immediate Lock',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              authProvider.immediateTimeoutEnabled
                  ? 'App locks immediately when sent to background'
                  : 'App uses timeout setting when sent to background',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
            value: authProvider.immediateTimeoutEnabled,
            onChanged: _toggleImmediateTimeout,
            secondary: Icon(
              authProvider.immediateTimeoutEnabled
                  ? Icons.lock
                  : Icons.lock_open,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ],
    );
  }

  // 🆕 Widget para configuración de ordenamiento
  Widget _buildSortingSettings() {
    if (_isLoadingSortPreference) {
      return const ListTile(
        leading: Icon(Icons.sort),
        title: Text('Event Sorting'),
        trailing: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return ListTile(
      leading: Icon(Icons.sort, color: Theme.of(context).colorScheme.primary),
      title: const Text(
        'Event Sorting',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        'Currently: ${_getSortOptionName(_selectedSortOption)}',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          fontSize: 12,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: _showSortOptionsDialog,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).settings,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Security Section
          Text(
            AppLocalizations.of(context).security,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _buildBiometricSettings(authProvider),
          ),

          const SizedBox(height: 24),

          // 🆕 Display & Organization Section
          Text(
            'Display & Organization',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _buildSortingSettings(),
          ),

          const SizedBox(height: 24),

          // Warning message for non-available biometric
          if (!_isBiometricAvailable && !_isCheckingBiometric) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'To use biometric authentication, please ensure your device supports it and you have enrolled biometric credentials in your device settings.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Info about timeout options
          if (authProvider.isBiometricAuthEnabled && _isBiometricAvailable) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Security Options',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '• Auto-lock Timeout: Sets how long the app stays unlocked after being sent to background\n'
                          '• Immediate Lock: App locks immediately when minimized, regardless of timeout setting',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.8),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
