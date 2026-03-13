import 'package:fan_app_interface/features/emergency/presentation/alert.dart';
import 'package:fan_app_interface/features/map/presentation/stadium_map_page.dart';
import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'Home.dart';
import 'features/map/data/services/local_map_cache.dart';
import 'features/navigation/data/services/user_position_service.dart';
import 'core/services/location_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalMapCache.init();
  await LocalMapCache.clear(); // Limpar cache antigo do estádio
  await UserPositionService.resetToDefault(); // Reset posição para instituto
  
  // Iniciar tracking GPS anónimo
  final locationService = LocationService();
  await locationService.init();
  locationService.startTracking();

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
