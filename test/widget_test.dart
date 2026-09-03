// test/widget_test.dart
import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/providers/auth_provider.dart';
import 'package:myapp/providers/event_provider.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('App renders Material 3 Expressive theme', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => EventProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ],
        child: M3EMaterialApp(
          data: M3EThemeData.light(),
          autoTheming: true,
          dynamicColoring: true,
          home: const Scaffold(
            body: Center(
              child: Text('Routine App'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Routine App'), findsOneWidget);
    final materialApp = tester.widget<M3EMaterialApp>(find.byType(M3EMaterialApp));
    expect(materialApp.data.useMaterial3, isTrue);
  });
}
