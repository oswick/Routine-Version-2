// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:myapp/config/app_theme.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/providers/theme_provider.dart';
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

  EventSortOption _selectedSortOption = EventSortOption.timeAscending;
  bool _isLoadingSortPreference = true;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
    _loadSortPreference();
  }

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

  Future<void> _saveSortPreference(EventSortOption option) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('event_sort_option', option.index);

      if (mounted) {
        setState(() => _selectedSortOption = option);

        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // FIX: was hardcoded 'Sort preference saved: ...'
            content: Text(
              '${l10n.sortPrefSaved}: ${_getSortOptionName(option)}',
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
            content: Text('${AppLocalizations.of(context).error}: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // FIX: was returning hardcoded English strings
  String _getSortOptionName(EventSortOption option) {
    final l10n = AppLocalizations.of(context);
    switch (option) {
      case EventSortOption.timeAscending:
        return l10n.sortTimeAscending;
      case EventSortOption.timeDescending:
        return l10n.sortTimeDescending;
      case EventSortOption.importance:
        return l10n.sortImportance;
      case EventSortOption.importanceAndTime:
        return l10n.sortImportanceAndTime;
      case EventSortOption.title:
        return l10n.sortTitle;
      case EventSortOption.category:
        return l10n.sortCategory;
    }
  }

  // FIX: was returning hardcoded English strings
  String _getSortOptionDescription(EventSortOption option) {
    final l10n = AppLocalizations.of(context);
    switch (option) {
      case EventSortOption.timeAscending:
        return l10n.sortDescTimeAscending;
      case EventSortOption.timeDescending:
        return l10n.sortDescTimeDescending;
      case EventSortOption.importance:
        return l10n.sortDescImportance;
      case EventSortOption.importanceAndTime:
        return l10n.sortDescImportanceAndTime;
      case EventSortOption.title:
        return l10n.sortDescTitle;
      case EventSortOption.category:
        return l10n.sortDescCategory;
    }
  }

  Future<void> _showSortOptionsDialog() async {
    final l10n = AppLocalizations.of(context);

    final result = await showDialog<EventSortOption>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          // FIX: was hardcoded 'Event Sorting'
          title: Text(l10n.eventSorting),
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
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
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
    final l10n = AppLocalizations.of(context);

    if (value) {
      AuthResult result = await BiometricService.authenticateWithResult();
      if (result.success) {
        await authProvider.setBiometricAuthEnabled(true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              // FIX: was hardcoded English
              content: Text(l10n.biometricEnabledSuccessfully),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? l10n.authenticationFailed),
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
              // FIX: was hardcoded English
              content: Text(l10n.biometricDisabled),
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
                '${l10n.authRequiredToChangeSettings} ${result.errorMessage ?? ''}',
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
    final l10n = AppLocalizations.of(context);

    final result = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context).autoLockTimeout),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: AuthProvider.timeoutOptions.map((minutes) {
              return RadioListTile<int>(
                // FIX: pass context so getTimeoutText uses l10n
                title: Text(AuthProvider.getTimeoutText(minutes, context)),
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
              // FIX: was hardcoded English
              content: Text(
                '${l10n.autoLockTimeoutSetTo} ${AuthProvider.getTimeoutText(result, context)}',
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
                '${l10n.authRequiredToChangeSettings} ${authResult.errorMessage ?? ''}',
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
    final l10n = AppLocalizations.of(context);

    AuthResult result = await BiometricService.authenticateWithResult();
    if (result.success) {
      await authProvider.setImmediateTimeout(value);
      await authProvider.setLastAuthTime();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // FIX: was hardcoded English
            content: Text(
              value ? l10n.immediateEnabledMessage : l10n.immediateDisabledMessage,
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
              '${l10n.authRequiredToChangeSettings} ${result.errorMessage ?? ''}',
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
    final l10n = AppLocalizations.of(context);

    if (_isCheckingBiometric) {
      return ListTile(
        leading: const Icon(Icons.fingerprint),
        title: Text(l10n.enableBiometricAuthentication),
        trailing: const SizedBox(
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
            l10n.enableBiometricAuthentication,
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
                  l10n.biometricNotAvailableDevice,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                )
              : authProvider.isBiometricAuthEnabled
                  ? Text(
                      l10n.appWillRequireBiometric,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
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
            title: Text(
              // FIX: was hardcoded 'Auto-lock Timeout'
              l10n.autoLockTimeout,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              // FIX: was hardcoded English via getTimeoutText without context
              '${l10n.currentlySetTo} ${AuthProvider.getTimeoutText(authProvider.authTimeoutMinutes, context)}'
              '${authProvider.immediateTimeoutEnabled ? ' ${l10n.overriddenByImmediateLock}' : ''}',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.6),
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
            title: Text(
              // FIX: was hardcoded 'Immediate Lock'
              l10n.immediateLock,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              // FIX: was hardcoded English
              authProvider.immediateTimeoutEnabled
                  ? l10n.appLocksImmediately
                  : l10n.appUsesTimeoutSetting,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.6),
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

  Widget _buildSortingSettings() {
    final l10n = AppLocalizations.of(context);

    if (_isLoadingSortPreference) {
      return ListTile(
        leading: const Icon(Icons.sort),
        // FIX: was hardcoded 'Event Sorting'
        title: Text(l10n.eventSorting),
        trailing: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return ListTile(
      leading:
          Icon(Icons.sort, color: Theme.of(context).colorScheme.primary),
      // FIX: was hardcoded 'Event Sorting'
      title: Text(
        l10n.eventSorting,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        // FIX: was hardcoded 'Currently: ...'
        '${l10n.currentlySorting}: ${_getSortOptionName(_selectedSortOption)}',
        style: TextStyle(
          color:
              Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          fontSize: 12,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: _showSortOptionsDialog,
    );
  }

  Widget _buildThemeSettings(ThemeProvider themeProvider) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Theme Mode Selector (SegmentedButton)
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment<ThemeMode>(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto_outlined),
                label: Text('Sistema'),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined),
                label: Text('Claro'),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined),
                label: Text('Oscuro'),
              ),
            ],
            selected: {themeProvider.themeMode},
            onSelectionChanged: (newSelection) {
              themeProvider.setThemeMode(newSelection.first);
            },
          ),
          const SizedBox(height: 16),

          // AMOLED Pure Black Toggle
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(
              Icons.nightlight_round,
              color: colorScheme.primary,
            ),
            title: const Text(
              'Negro Puro (AMOLED)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'Fondo totalmente negro para ahorrar batería',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            value: themeProvider.isAmoled,
            onChanged: (val) => themeProvider.setAmoled(val),
          ),
          const Divider(height: 24),

          // Dynamic Colors (Material You) Toggle
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(
              Icons.palette_outlined,
              color: colorScheme.primary,
            ),
            title: const Text(
              'Color Dinámico (Material You)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'Usar los colores del fondo de pantalla del sistema',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            value: themeProvider.useDynamicColor,
            onChanged: (val) => themeProvider.setUseDynamicColor(val),
          ),

          // Expressive Seeds Palette
          if (!themeProvider.useDynamicColor) ...[
            const SizedBox(height: 12),
            Text(
              'Paleta de Semilla Expresiva',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: AppThemeSeed.values.map((seed) {
                final isSelected = themeProvider.selectedSeed == seed;
                return InkWell(
                  onTap: () => themeProvider.setSelectedSeed(seed),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? seed.color.withOpacity(0.18)
                          : colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? seed.color : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: seed.color,
                            shape: BoxShape.circle,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 12, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          seed.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? seed.color : colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          l10n.settings,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Theme & Appearance Section (Material 3 Expressive)
          Text(
            'Aspecto y Tema (Material 3)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outlineVariant.withOpacity(0.3),
              ),
            ),
            child: _buildThemeSettings(themeProvider),
          ),

          const SizedBox(height: 24),

          // Security Section
          Text(
            l10n.security,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outlineVariant.withOpacity(0.3),
              ),
            ),
            child: _buildBiometricSettings(authProvider),
          ),

          const SizedBox(height: 24),

          // Display & Organization Section
          Text(
            l10n.displayAndOrganization,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outlineVariant.withOpacity(0.3),
              ),
            ),
            child: _buildSortingSettings(),
          ),

          const SizedBox(height: 24),

          // Warning message for non-available biometric
          if (!_isBiometricAvailable && !_isCheckingBiometric) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: colorScheme.onErrorContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.biometricSetupMessage,
                      style: TextStyle(
                        color: colorScheme.onErrorContainer,
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
          if (authProvider.isBiometricAuthEnabled &&
              _isBiometricAvailable) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.securityOptions,
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.securityOptionsDescription,
                          style: TextStyle(
                            color: colorScheme.primary.withOpacity(0.8),
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