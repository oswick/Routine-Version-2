// lib/screens/settings_screen.dart
import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
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
        M3ESnackbar.show(
          context,
          // FIX: was hardcoded 'Sort preference saved: ...'
          message: '${l10n.sortPrefSaved}: ${_getSortOptionName(option)}',
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      debugPrint('Error saving sort preference: $e');
      if (mounted) {
        M3ESnackbar.show(
          context,
          message: '${AppLocalizations.of(context).error}: $e',
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

    final result = await M3EDialog.show<EventSortOption>(
      context,
      dialog: M3EDialog(
        // FIX: was hardcoded 'Event Sorting'
        title: l10n.eventSorting,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: EventSortOption.values.map((option) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: M3ERadio<EventSortOption>(
                  value: option,
                  groupValue: _selectedSortOption,
                  onChanged: (value) {
                    Navigator.of(context).pop(value);
                  },
                  label: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_getSortOptionName(option)),
                      Text(
                        _getSortOptionDescription(option),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          M3EButton.text(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).cancel),
          ),
        ],
      ),
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
          M3ESnackbar.show(
            context,
            // FIX: was hardcoded English
            message: l10n.biometricEnabledSuccessfully,
          );
        }
      } else {
        if (mounted) {
          M3ESnackbar.show(
            context,
            message: result.errorMessage ?? l10n.authenticationFailed,
            duration: const Duration(seconds: 4),
          );
        }
      }
    } else {
      AuthResult result = await BiometricService.authenticateWithResult();
      if (result.success) {
        await authProvider.setBiometricAuthEnabled(false);
        if (mounted) {
          M3ESnackbar.show(
            context,
            // FIX: was hardcoded English
            message: l10n.biometricDisabled,
          );
        }
      } else {
        if (mounted) {
          M3ESnackbar.show(
            context,
            message:
                '${l10n.authRequiredToChangeSettings} ${result.errorMessage ?? ''}',
            duration: const Duration(seconds: 4),
          );
        }
      }
    }
  }

  Future<void> _showTimeoutOptionsDialog(AuthProvider authProvider) async {
    final l10n = AppLocalizations.of(context);

    final result = await M3EDialog.show<int>(
      context,
      dialog: M3EDialog(
        title: AppLocalizations.of(context).autoLockTimeout,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AuthProvider.timeoutOptions.map((minutes) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: M3ERadio<int>(
                // FIX: pass context so getTimeoutText uses l10n
                value: minutes,
                groupValue: authProvider.authTimeoutMinutes,
                onChanged: (value) {
                  Navigator.of(context).pop(value);
                },
                label: Text(AuthProvider.getTimeoutText(minutes, context)),
              ),
            );
          }).toList(),
        ),
        actions: [
          M3EButton.text(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).cancel),
          ),
        ],
      ),
    );

    if (result != null && result != authProvider.authTimeoutMinutes) {
      AuthResult authResult = await BiometricService.authenticateWithResult();
      if (authResult.success) {
        await authProvider.setAuthTimeout(result);
        await authProvider.setLastAuthTime();

        if (mounted) {
          M3ESnackbar.show(
            context,
            // FIX: was hardcoded English
            message:
                '${l10n.autoLockTimeoutSetTo} ${AuthProvider.getTimeoutText(result, context)}',
          );
        }
      } else {
        if (mounted) {
          M3ESnackbar.show(
            context,
            message:
                '${l10n.authRequiredToChangeSettings} ${authResult.errorMessage ?? ''}',
            duration: const Duration(seconds: 4),
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
        M3ESnackbar.show(
          context,
          // FIX: was hardcoded English
          message:
              value ? l10n.immediateEnabledMessage : l10n.immediateDisabledMessage,
          duration: const Duration(seconds: 3),
        );
      }
    } else {
      if (mounted) {
        M3ESnackbar.show(
          context,
          message:
              '${l10n.authRequiredToChangeSettings} ${result.errorMessage ?? ''}',
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  Widget _buildBiometricSettings(AuthProvider authProvider) {
    final l10n = AppLocalizations.of(context);

    if (_isCheckingBiometric) {
      return M3EListItem(
        leading: const Icon(Icons.fingerprint),
        headline: l10n.enableBiometricAuthentication,
        trailing: const SizedBox(
          width: 20,
          height: 20,
          child: M3ELoadingIndicator(),
        ),
      );
    }
    return Column(
      children: [
        M3EListItem(
          leading: Icon(
            Icons.fingerprint,
            color: _isBiometricAvailable
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
          headline: l10n.enableBiometricAuthentication,
          supportingText: !_isBiometricAvailable
              ? l10n.biometricNotAvailableDevice
              : authProvider.isBiometricAuthEnabled
                  ? l10n.appWillRequireBiometric
                  : null,
          trailing: M3ESwitch(
            value: authProvider.isBiometricAuthEnabled,
            onChanged: _isBiometricAvailable ? _toggleBiometricAuth : null,
          ),
        ),

        if (authProvider.isBiometricAuthEnabled && _isBiometricAvailable) ...[
          const M3EDivider(),

          M3EListItem(
            leading: Icon(
              Icons.timer,
              color: Theme.of(context).colorScheme.primary,
            ),
            // FIX: was hardcoded 'Auto-lock Timeout'
            headline: l10n.autoLockTimeout,
            // FIX: was hardcoded English via getTimeoutText without context
            supportingText:
                '${l10n.currentlySetTo} ${AuthProvider.getTimeoutText(authProvider.authTimeoutMinutes, context)}'
                '${authProvider.immediateTimeoutEnabled ? ' ${l10n.overriddenByImmediateLock}' : ''}',
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: authProvider.immediateTimeoutEnabled
                ? null
                : () => _showTimeoutOptionsDialog(authProvider),
          ),

          const M3EDivider(),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                Icon(
                  authProvider.immediateTimeoutEnabled
                      ? Icons.lock
                      : Icons.lock_open,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // FIX: was hardcoded 'Immediate Lock'
                        l10n.immediateLock,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
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
                    ],
                  ),
                ),
                M3ESwitch(
                  value: authProvider.immediateTimeoutEnabled,
                  onChanged: _toggleImmediateTimeout,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSortingSettings() {
    final l10n = AppLocalizations.of(context);

    if (_isLoadingSortPreference) {
      return M3EListItem(
        leading: const Icon(Icons.sort),
        // FIX: was hardcoded 'Event Sorting'
        headline: l10n.eventSorting,
        trailing: const SizedBox(
          width: 20,
          height: 20,
          child: M3ELoadingIndicator(),
        ),
      );
    }

    return M3EListItem(
      leading:
          Icon(Icons.sort, color: Theme.of(context).colorScheme.primary),
      // FIX: was hardcoded 'Event Sorting'
      headline: l10n.eventSorting,
      // FIX: was hardcoded 'Currently: ...'
      supportingText:
          '${l10n.currentlySorting}: ${_getSortOptionName(_selectedSortOption)}',
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: _showSortOptionsDialog,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: M3EAppBar.top(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            l10n.settings,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
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