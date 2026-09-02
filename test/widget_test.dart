// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/config/app_theme.dart';
import 'package:myapp/providers/auth_provider.dart';
import 'package:myapp/providers/event_provider.dart';
import 'package:myapp/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App renders MaterialApp with Material 3 Expressive theme', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => EventProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ],
        child: Consumer<ThemeProvider>(
          builder: (context, themeProvider, _) {
            return MaterialApp(
              theme: AppTheme.lightTheme(
                seedColor: themeProvider.currentSeedColor,
              ),
              darkTheme: AppTheme.darkTheme(
                seedColor: themeProvider.currentSeedColor,
                isAmoled: themeProvider.isAmoled,
              ),
              themeMode: themeProvider.themeMode,
              home: const Scaffold(
                body: Center(
                  child: Text('Routine App'),
                ),
              ),
            );
          },
        ),
      ),
    );

    expect(find.text('Routine App'), findsOneWidget);
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.useMaterial3, isTrue);
  });
}
