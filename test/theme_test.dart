// test/theme_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/config/app_theme.dart';
import 'package:myapp/providers/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppTheme Tests', () {
    test('Light Theme builds with Material 3 and Expressive color scheme', () {
      final theme = AppTheme.lightTheme();
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.brightness, Brightness.light);
      expect(theme.cardTheme.shape, isA<RoundedRectangleBorder>());
      expect(theme.floatingActionButtonTheme.shape, isA<RoundedRectangleBorder>());
    });

    test('Dark Theme builds with Material 3 and AMOLED support', () {
      final standardDark = AppTheme.darkTheme(isAmoled: false);
      expect(standardDark.useMaterial3, isTrue);
      expect(standardDark.brightness, Brightness.dark);

      final amoledDark = AppTheme.darkTheme(isAmoled: true);
      expect(amoledDark.colorScheme.surface, Colors.black);
      expect(amoledDark.scaffoldBackgroundColor, Colors.black);
    });

    test('Theme generates properly with custom seeds', () {
      for (final seed in AppThemeSeed.values) {
        final light = AppTheme.lightTheme(seedColor: seed.color);
        final dark = AppTheme.darkTheme(seedColor: seed.color);
        expect(light.colorScheme.primary, isNotNull);
        expect(dark.colorScheme.primary, isNotNull);
      }
    });
  });

  group('ThemeProvider Tests', () {
    test('Initializes with default values', () {
      final provider = ThemeProvider();
      expect(provider.themeMode, ThemeMode.system);
      expect(provider.isAmoled, isFalse);
      expect(provider.selectedSeed, AppThemeSeed.indigo);
    });

    test('Allows changing ThemeMode, Seed, and AMOLED', () async {
      final provider = ThemeProvider();

      await provider.setThemeMode(ThemeMode.dark);
      expect(provider.themeMode, ThemeMode.dark);

      await provider.setAmoled(true);
      expect(provider.isAmoled, isTrue);

      await provider.setSelectedSeed(AppThemeSeed.emerald);
      expect(provider.selectedSeed, AppThemeSeed.emerald);
      expect(provider.useDynamicColor, isFalse);
    });
  });
}
