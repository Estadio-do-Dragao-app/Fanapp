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
    // TODO: Refactor DestinationSelectionPage to accept MapService, RoutingService, etc. via constructor
    // to allow proper mocking. Currently, the widget creates its own services, making it impossible
    // to test in isolation on CI without real network/GPS.
    testWidgets('renders without error when POI list is empty', (tester) async {
      // Skipped because it requires real API calls and GPS permissions.
    }, skip: 'Requires dependency injection to mock services');

    testWidgets('shows POI items when service returns results', (tester) async {
      // Skipped for the same reason.
    }, skip: 'Requires dependency injection to mock services');
  });
}