import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'features/map/presentation/pages/map_page.dart';
import 'features/poi/presentation/navbar.dart';
import 'features/hub/presentation/search_bar.dart';
import 'features/hub/presentation/menu_button.dart';
import 'features/map/presentation/filter_button.dart';
import 'features/poi/presentation/saved_places_sheet.dart';
import 'home_view_model.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final GlobalKey<MapPageState> _mapPageKey = GlobalKey<MapPageState>();
  final GlobalKey<FilterButtonState> _filterButtonKey = GlobalKey<FilterButtonState>();
  late final HomeViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = HomeViewModel();
    _viewModel.onEmergencyAlert = _openEmergencyTestFlow;
    _viewModel.initConsent(context);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _openEmergencyTestFlow() {
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/emergency-alert', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          return Stack(
            children: [
              MapPage(
                key: _mapPageKey,
                showHeatmap: _viewModel.showHeatmap,
                onHeatmapConnectionError: () => _viewModel.updateHealthStatus(false),
                onHeatmapConnectionSuccess: () {
                  if (!_viewModel.isHeatmapAvailable) _viewModel.updateHealthStatus(true);
                },
                onFloorChanged: _viewModel.setFloor,
                currentFloor: _viewModel.currentFloor,
                avoidStairs: _viewModel.avoidStairs,
                onPOIPanelChanged: _viewModel.setPOIPanelOpen,
              ),
              if (_viewModel.isFilterExpanded)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      _filterButtonKey.currentState?.closeMenu();
                      _viewModel.setFilterExpanded(false);
                    },
                    child: Container(color: Colors.transparent),
                  ),
                ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 240,
                  child: Navbar(
                    avoidStairs: _viewModel.avoidStairs,
                    onNavigationEnd: () {
                      _mapPageKey.currentState?.reloadUserPosition();
                    },
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 130,
                right: 16,
                child: FilterButton(
                  key: _filterButtonKey,
                  showHeatmap: _viewModel.showHeatmap,
                  isHeatmapAvailable: _viewModel.isHeatmapAvailable,
                  onHeatmapChanged: _viewModel.setHeatmap,
                  avoidStairs: _viewModel.avoidStairs,
                  onAvoidStairsChanged: _viewModel.setAvoidStairs,
                  onExpandedChanged: () {
                    _viewModel.setFilterExpanded(_filterButtonKey.currentState?.isExpanded ?? false);
                  },
                ),
              ),
              if (!_viewModel.isPOIPanelOpen)
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
                            avoidStairs: _viewModel.avoidStairs,
                            onPOISelected: (poi) {
                              _mapPageKey.currentState?.openPOIDetails(poi);
                            },
                            onNavigationEnd: () {
                              _mapPageKey.currentState?.reloadUserPosition();
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
                            child: const Icon(Icons.search, color: Colors.white, size: 30),
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
              if (!_viewModel.isPOIPanelOpen)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: MenuButton(
                    icon: Icons.star,
                    onTap: () async {
                      await SavedPlacesSheet.show(
                        context,
                        onPOISelected: (poi) {
                          _mapPageKey.currentState?.openPOIDetails(poi);
                        },
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
