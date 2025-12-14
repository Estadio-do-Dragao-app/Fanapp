import 'package:fan_app_interface/features/emergency/presentation/alert.dart';
import 'package:fan_app_interface/features/map/presentation/stadium_map_page.dart';
import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'Home.dart';
import 'features/map/data/services/local_map_cache.dart';
import 'features/map/data/services/waittime_cache.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalMapCache.init();
  WaittimeCache().start(); // Start listening to MQTT wait time updates
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
      routes: {
        '/map': (context) => const StadiumMapPage(),
        '/emergency-alert': (context) => const EmergencyAlertPage(),
      },
    );
  }
}
