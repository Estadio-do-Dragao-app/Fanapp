import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fan_app_interface/features/emergency/presentation/alert.dart';
import 'package:fan_app_interface/features/map/presentation/fan_map_page.dart';
import 'package:fan_app_interface/core/utils/top_feedback.dart';
import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'Home.dart';
import 'features/map/data/services/local_map_cache.dart';
import 'features/navigation/data/services/user_position_service.dart';
import 'core/services/location_service.dart';
import 'core/config/api_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalMapCache.init();
  await ApiConfig.init(); // Detetar backend (VM ou Local)
  
  
  // Iniciar tracking GPS anónimo
  final locationService = LocationService();
  await locationService.init();
  try {
    await locationService.startTracking();
  } catch (e, stackTrace) {
    debugPrint('Error starting GPS tracking: $e');
    debugPrint('Stack trace: $stackTrace');
  }

  await UserPositionService.clearPosition(); // Limpar posições
  runApp(const MyApp());

}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool? _isOnline;

  @override
  void initState() {
    super.initState();
    // Check initial state after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final results = await Connectivity().checkConnectivity();
      await _handleConnectivityChange(results);
    });
    // Listen for OS-level connectivity events, confirm with HTTP ping
    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      _handleConnectivityChange,
    );
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _handleConnectivityChange(
    List<ConnectivityResult> results,
  ) async {
    final isOnline = results.any((r) => r != ConnectivityResult.none);

    if (!mounted) return;

    final previousStatus = _isOnline;
    _isOnline = isOnline;

    if (previousStatus == isOnline) return;
    // Don't show "reconnected" on first check when already online at startup
    if (previousStatus == null && isOnline) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _navigatorKey.currentContext;
      if (context == null) return;

      final localizations = AppLocalizations.of(context)!;
      if (!isOnline) {
        AppTopFeedback.showWarning(
          context,
          localizations.internetDisconnected,
          duration: const Duration(seconds: 4),
          backgroundColor: const Color(0xFFC62828),
          icon: Icons.wifi_off_rounded,
        );
      } else {
        AppTopFeedback.showWarning(
          context,
          localizations.internetReconnected,
          duration: const Duration(seconds: 3),
          backgroundColor: const Color(0xFF2E7D32),
          icon: Icons.wifi_rounded,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
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
        '/map': (context) => const FanMapPage(),
        '/emergency-alert': (context) => const EmergencyAlertPage(),
      },
    );
  }
}
