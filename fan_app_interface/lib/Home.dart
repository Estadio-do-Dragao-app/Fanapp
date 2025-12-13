import 'package:flutter/material.dart';
import 'dart:async';
import 'l10n/app_localizations.dart';
import 'features/map/presentation/pages/map_page.dart';
import 'features/poi/presentation/navbar.dart';
import 'features/hub/presentation/search_bar.dart';
import 'features/hub/presentation/menu_button.dart';
import 'features/map/presentation/filter_button.dart';
import 'features/ticket/presentation/ticket_menu.dart';
import 'features/map/data/services/congestion_service.dart';
import 'features/navigation/data/services/user_position_service.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  // GlobalKey para acessar o state do MapPage (agora público)
  final GlobalKey<MapPageState> _mapPageKey = GlobalKey<MapPageState>();
  final CongestionService _congestionService = CongestionService();

  // Estado do heatmap
  bool _showHeatmap = false;
  bool _isHeatmapAvailable = true;
  Timer? _healthCheckTimer;

  // Estado do piso
  int _currentFloor = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialFilter();
    _checkCongestionHealth();
    // Iniciar timer de 30s (só verifica quando heatmap está desligado)
    _startHealthCheckTimer();
  }

  Future<void> _loadInitialFilter() async {
    final pos = await UserPositionService.getPosition();
    if (mounted) {
      setState(() {
        _currentFloor = pos.level;
      });
    }
  }

  @override
  void dispose() {
    _healthCheckTimer?.cancel();
    super.dispose();
  }

  /// Inicia timer de verificação de saúde (30 segundos)
  void _startHealthCheckTimer() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      // Só verifica quando heatmap está desligado
      if (!_showHeatmap) {
        _checkCongestionHealth();
      }
    });
  }

  Future<void> _checkCongestionHealth() async {
    final isConnected = await _congestionService.connect();
    _updateHealthStatus(isConnected);
  }

  /// Atualiza estado de disponibilidade (chamado pelo timer ou pelo MapPage)
  void _updateHealthStatus(bool isHealthy) {
    if (mounted && _isHeatmapAvailable != isHealthy) {
      setState(() {
        _isHeatmapAvailable = isHealthy;
        // Desativar heatmap automaticamente se serviço falhar
        if (!isHealthy && _showHeatmap) {
          _showHeatmap = false;
        }
      });
    }
  }

  /// Callback chamado quando há erro de conexão do heatmap (10s updates)
  void _onHeatmapConnectionError() {
    _updateHealthStatus(false);
  }

  /// Callback chamado quando heatmap recebe dados com sucesso
  void _onHeatmapConnectionSuccess() {
    if (!_isHeatmapAvailable) {
      _updateHealthStatus(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          MapPage(
            key: _mapPageKey,
            showHeatmap: _showHeatmap,
            onHeatmapConnectionError: _onHeatmapConnectionError,
            onHeatmapConnectionSuccess: _onHeatmapConnectionSuccess,
            onFloorChanged: (floor) {
              if (_currentFloor != floor) {
                setState(() {
                  _currentFloor = floor;
                });
              }
            },
            currentFloor: _currentFloor,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 240,
              color: Colors.transparent,
              child: Navbar(
                onNavigationEnd: () {
                  _mapPageKey.currentState?.reloadUserPosition();
                },
              ),
            ),
          ),
          // Filter button - top right below navbar
          Positioned(
            top: MediaQuery.of(context).padding.top + 100,
            right: 16,
            child: FilterButton(
              showHeatmap: _showHeatmap,
              isHeatmapAvailable: _isHeatmapAvailable,
              currentFloor: _currentFloor,
              onFloorChanged: (floor) {
                setState(() {
                  _currentFloor = floor;
                });
              },
              onHeatmapChanged: (value) {
                setState(() {
                  _showHeatmap = value;
                });
                // Se está a ligar, verificar saúde imediatamente
                if (value) {
                  _checkCongestionHealth();
                }
              },
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 92,
            child: GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  isDismissible: true,
                  enableDrag: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  builder: (context) {
                    return SearchBarBottomSheet(
                      onPOISelected: (poi) {
                        // Fazer zoom no POI após fechar a barra de pesquisa
                        _mapPageKey.currentState?.zoomToPOI(poi);
                      },
                    );
                  },
                );
              },
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF161A3E),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.diagonal3Values(-1.0, 1.0, 1.0),
                      child: const Icon(
                        Icons.search,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.search,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Gabarito',
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: MenuButton(
              onTap: () {
                TicketMenu.show(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}
