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
    // O widget real chama-se DestinationSelectionPage (conforme o arquivo).
    // Estes testes estão a skip porque o widget depende de serviços reais (rede, GPS)
    // e não foi desenhado para injeção de dependências.
    testWidgets('renders without error when POI list is empty', (tester) async {
      // Skip porque requer refatoração para testes isolados
    }, skip: true);

    testWidgets('shows POI items when service returns results', (tester) async {
      // Skip pelo mesmo motivo
    }, skip: true);
  });
}