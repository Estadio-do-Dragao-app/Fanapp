import 'package:flutter/material.dart';
import '../../map/presentation/stadium_map_page.dart';
import '../../map/data/models/poi_model.dart';
import '../../map/data/services/map_service.dart';
import '../../map/data/services/routing_service.dart';
import '../../navigation/presentation/navigation_page.dart';
import 'package:fan_app_interface/l10n/app_localizations.dart';
import 'package:fan_app_interface/core/utils/geographic_utils.dart';
import 'dart:math';
import 'dart:async';
import 'dart:ui';

class EmergencyAlertPage extends StatefulWidget {
  const EmergencyAlertPage({Key? key}) : super(key: key);

  @override
  State<EmergencyAlertPage> createState() => _EmergencyAlertPageState();
}

class _EmergencyAlertPageState extends State<EmergencyAlertPage>
    with SingleTickerProviderStateMixin {
  final MapService _mapService = MapService();
  final RoutingService _routingService = RoutingService();

  int _remainingSeconds = 3;
  Timer? _redirectTimer;
  List<POIModel>? _exits;

  @override
  void initState() {
    super.initState();

    _loadExits();
    // Auto-redirect timer
    _startedirectTimer();
  }

  Future<void> _loadExits() async {
    try {
      final pois = await _mapService.getAllPOIs();
      final exits = pois
          .where(
            (poi) =>
                poi.category.toLowerCase() == 'emergency_exit' ||
                poi.category.toLowerCase() == 'exit',
          )
          .toList();
      if (mounted) {
        setState(() {
          _exits = exits;
        });
      }
    } catch (e) {
      print('[EmergencyAlert] Erro ao carregar saídas para o fundo: $e');
    }
  }

  void _startedirectTimer() {
    _redirectTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _remainingSeconds--;
        if (_remainingSeconds <= 0) {
          timer.cancel();
          _goToEmergencyNavigation();
        }
      });
    });
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    super.dispose();
  }

  void _goToEmergencyNavigation() async {
    try {
      // Buscar POIs e nodes
      final pois = await _mapService.getAllPOIs();
      final nodes = await _mapService.getAllNodes();

      // PRIMEIRO: Encontrar saídas de emergência
      final exits = _exits ?? pois
          .where(
            (poi) =>
                poi.category.toLowerCase() == 'emergency_exit' ||
                poi.category.toLowerCase() == 'exit',
          )
          .toList();

      if (exits.isEmpty) {
        print('[EmergencyAlert] Nenhuma saída encontrada!');
        Navigator.of(context).pushReplacementNamed('/map');
        return;
      }

      // SEGUNDO: Obter posição atual do utilizador
      final savedPosition = await GeographicUtils.getCurrentUserPosition();
      
      if (savedPosition == null) {
         if (!mounted) return;
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text(AppLocalizations.of(context)!.gpsRequiredMessage),
             backgroundColor: Colors.orange,
           ),
         );
         Navigator.of(context).pushReplacement(
           MaterialPageRoute(
             builder: (context) => StadiumMapPage(
               customPOIsToShow: exits,
               zoomOutToPOIs: true,
               isEmergency: true,
             ),
           ),
         );
         return;
      }
      
      double startX = savedPosition.x;
      double startY = savedPosition.y;
      int startLevel = savedPosition.level;

      print(
        '[EmergencyAlert] Posição do utilizador: ($startX, $startY, level=$startLevel)',
      );

      // Encontrar saída mais próxima usando a posição REAL do utilizador
      POIModel? nearestExit;
      double minDistance = double.infinity;

      for (final exit in exits) {
        // Calcular distância euclidiana usando coordenadas do utilizador
        final dx = exit.x - startX;
        final dy = exit.y - startY;
        final distance = sqrt(dx * dx + dy * dy);

        // Adicionar penalidade se saída está em nível diferente (escadas demoram mais)
        final levelPenalty = (exit.level - startLevel).abs() * 50.0;
        final totalDistance = distance + levelPenalty;

        print(
          '[EmergencyAlert] Saída ${exit.name} (${exit.id}): dist=$distance, level=${exit.level}, total=$totalDistance',
        );

        if (totalDistance < minDistance) {
          minDistance = totalDistance;
          nearestExit = exit;
        }
      }

      if (nearestExit == null) {
        Navigator.of(context).pushReplacementNamed('/map');
        return;
      }

      print(
        '[EmergencyAlert] Saída mais próxima: ${nearestExit.name} (${nearestExit.id})',
      );

      final route = await _routingService.getRouteToPOI(
        startX: startX,
        startY: startY,
        startLevel: startLevel,
        poiId: nearestExit.id,
      );

      // Navegar para página de navegação de emergência
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => NavigationPage(
              route: route!,
              destination: nearestExit!,
              nodes: nodes,
              isEmergency: true,
              initialX: startX,
              initialY: startY,
              initialLevel: startLevel,
            ),
          ),
        );
      }
    } catch (e) {
      print('[EmergencyAlert] Erro ao calcular rota: $e');
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/map');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      body: Builder(
        builder: (context) {
          return Stack(
            children: [
              // Fundo (mapa)
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                  child: StadiumMapPage(
                    customPOIsToShow: _exits ?? [],
                    zoomOutToPOIs: _exits != null && _exits!.isNotEmpty,
                    isEmergency: true,
                    interactivePOIs: false,
                  ),
                ),
              ),
              // Conteúdo respeita SafeArea — a BORDA NÃO
              SafeArea(
                child: Stack(
                  children: [
                    // Conteúdo central
                    Positioned(
                      top: MediaQuery.of(context).size.height * 0.15,
                      left: 1,
                      right: 1,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              color: const Color(0xFFBD453D),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.warning_rounded,
                              color: Colors.white,
                              size: 150,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            localizations.evacuation,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Gabarito',
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Botão MAP
                    Positioned(
                      bottom: 12,
                      left: 32,
                      right: 32,
                      child: GestureDetector(
                        onTap: _goToEmergencyNavigation,
                        child: Container(
                          height: 94,
                          decoration: BoxDecoration(
                            color: const Color(0xFFBD453D),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Center(
                                child: Text(
                                  localizations.map,
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontFamily: 'Gabarito',
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                child: Text(
                                  '${_remainingSeconds}s',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Colors.white70,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
