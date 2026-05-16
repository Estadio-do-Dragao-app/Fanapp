import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fan_app_interface/l10n/app_localizations.dart';
import 'package:fan_app_interface/features/map/presentation/fan_map_page.dart';

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
  group('FanMapPage Widget Tests', () {
    testWidgets('renders map and initial UI elements (smoke test)', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(_wrap(const FanMapPage()));
        await tester.pumpAndSettle(const Duration(seconds: 2));
      });
      expect(tester.takeException(), isNull);
    });
  });
}