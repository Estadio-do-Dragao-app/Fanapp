import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'Home.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (locale, supportedLocales) {
        // Se a língua do dispositivo é português, usa português
        if (locale != null && locale.languageCode == 'pt') {
          return const Locale('pt');
        }
        // Para todas as outras línguas (incluindo inglês), usa inglês como fallback
        return const Locale('en');
      },
      title: 'Fan App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const Home(),
    );
  }
}