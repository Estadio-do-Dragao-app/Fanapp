import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fan_app_interface/l10n/app_localizations.dart';
import 'package:fan_app_interface/features/poi/presentation/destination_selection.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('pt')],
    home: Scaffold(body: child),
  );
}

void main() {
  group('DestinationSelectionPage Widget', () {
    testWidgets('renders without crashing (allowing network failures)', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(_wrap(
          const DestinationSelectionPage(categoryId: 'wc'),
        ));
        await tester.pumpAndSettle(const Duration(seconds: 3));
      });
      // Even if network calls fail, the widget should not crash.
      // Any exception during runAsync will be caught and test will fail.
      expect(tester.takeException(), isNull);
    });
  });
}