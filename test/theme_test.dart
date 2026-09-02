// test/theme_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/config/app_theme.dart';
import 'package:myapp/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppTheme Tests', () {
    testWidgets('Light Theme builds with Material 3 and Expressive color scheme', (tester) async {
      final theme = AppTheme.lightTheme();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(body: Center(child: Text('Light'))),
        ),
      );
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.brightness, Brightness.light);
      expect(theme.cardTheme.shape, isA<RoundedRectangleBorder>());
      expect(theme.floatingActionButtonTheme.shape, isA<RoundedRectangleBorder>());
    });

    testWidgets('Dark Theme builds with Material 3 and AMOLED support', (tester) async {
      final standardDark = AppTheme.darkTheme(isAmoled: false);
      final amoledDark = AppTheme.darkTheme(isAmoled: true);

      await tester.pumpWidget(
        MaterialApp(
          darkTheme: amoledDark,
          themeMode: ThemeMode.dark,
          home: const Scaffold(body: Center(child: Text('Dark'))),
        ),
      );

      expect(standardDark.useMaterial3, isTrue);
      expect(standardDark.brightness, Brightness.dark);
      expect(amoledDark.colorScheme.surface, Colors.black);
      expect(amoledDark.scaffoldBackgroundColor, Colors.black);
    });

    testWidgets('Theme generates properly with custom seeds', (tester) async {
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
