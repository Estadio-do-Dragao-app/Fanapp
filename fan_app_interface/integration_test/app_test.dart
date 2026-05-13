import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fan_app_interface/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-End App Test', () {
    testWidgets('App starts and shows Home screen', (WidgetTester tester) async {
      // Start the app
      await app.main();
      
      // Wait for app to finish loading
      await tester.pump(const Duration(seconds: 2));

      // Verify that MaterialApp exists
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
