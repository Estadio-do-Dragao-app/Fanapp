import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';

import 'package:latlong2/latlong.dart';
import '../../map/data/models/route_model.dart';
import '../../map/data/models/node_model.dart';
import '../../map/data/models/poi_model.dart';
import '../../map/data/services/routing_service.dart';
import '../../map/presentation/stadium_map_page.dart';
import '../../poi/presentation/poi_details_sheet.dart';
import '../domain/navigation_controller.dart';
import '../domain/models/reroute_event.dart';
import 'widgets/navigation_header.dart';
import 'widgets/navigation_bottom_sheet.dart';
import 'widgets/reroute_popup.dart';
import '../../../Home.dart';

/// Página principal de navegação (modo normal - azul)
class NavigationPage extends StatefulWidget {
  final RouteModel route;
  final POIModel destination;
  final List<NodeModel> nodes;
  final double? initialX;
  final double? initialY;
  final int? initialLevel;
  final bool
  isEmergency; // FIX 1: moved inside constructor params (was dangling field)

  const NavigationPage({
    super.key,
    required this.route,
    required this.destination,
    required this.nodes,
    this.initialX,
    this.initialY,
    this.initialLevel,
    this.isEmergency = false,
  });

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage>
    with TickerProviderStateMixin {
  late NavigationController _controller;
  late final AnimatedMapController _animatedMapController;
  final RoutingService _routingService = RoutingService();

  bool _showHeatmap = false;

  // State for reroute popup
  bool _showReroutePopup = false;
  RerouteEvent? _rerouteEvent;

  // Track bottom sheet expansion state
  bool _isBottomSheetExpanded = false;

  // Track if the map should follow the user position
  bool _isFollowingUser = true;

  // Preview route to show when selecting a new destination mid-navigation
  RouteModel? _previewRoute;
  String _lastRouteSignature = '';

  // Timer to resume user tracking after 5 seconds of inactivity
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    _lastRouteSignature = _routeSignature(widget.route);

    // Plugin: controlador com animações suaves
    _animatedMapController = AnimatedMapController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );

    _controller = NavigationController(
      route: widget.route,
      destination: widget.destination,
      allNodes: widget.nodes,
      initialX: widget.initialX,
      initialY: widget.initialY,
      initialLevel: widget.initialLevel,
    );
    _controller.addListener(_onNavigationUpdate);

    // Escutar eventos de reroute
    _controller.rerouteStream.listen((event) {
      if (!mounted) return;
      if (widget.isEmergency) {
        print('[NavigationPage] Emergency mode: reroute change ignored.');
        return;
      }
      print("[NavigationPage] 🔔 Reroute event received!");
      setState(() {
        _rerouteEvent = event;
        _showReroutePopup = true;
      });
    });
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _controller.removeListener(_onNavigationUpdate);
    _controller.dispose();
    _animatedMapController.dispose();
    super.dispose();
  }

  void _onNavigationUpdate() {
    if (!mounted) return;
    final currentSignature = _routeSignature(_controller.route);
    print(
      '[NavigationPage] 🔄 Update: index=${_controller.tracker.currentWaypointIndex}',
    );
    setState(() {
      // Se a rota mudou (reroute), limpar qualquer preview antigo
      // e forçar ciclo visual limpo no mapa.
      if (currentSignature != _lastRouteSignature) {
        _lastRouteSignature = currentSignature;
        _previewRoute = null;
        print('[NavigationPage] Route signature changed: $currentSignature');
      }
    });

    if (_isFollowingUser) {
      _followUserPosition();
    }

    if (_controller.hasArrived) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _exitNavigation();
        }
      });
    }
  }

  void _exitNavigation() async {
    if (_controller.isNavigating) {
      await _controller.endNavigation();
    }

    if (!mounted) return;

    if (widget.isEmergency) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const Home()),
        (route) => false,
      );
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _followUserPosition() {
    final tracker = _controller.tracker;
    final userLat = tracker.currentY;
    final userLng = tracker.currentX;

    try {
      _animatedMapController.animateTo(
        dest: LatLng(userLat, userLng),
        zoom: 20.0,
      );
    } catch (e) {
      // Mapa ainda não renderizado, ignorar
    }
  }

  Future<void> _endNavigation() async {
    await _controller.endNavigation();
    if (mounted) {
      _exitNavigation();
    }
  }

  /// Shows a sheet for switching destination mid-navigation
  void _showSwitchDestinationSheet(POIModel poi) async {
    if (widget.isEmergency) {
      print('[NavigationPage] Emergency mode: destination switch blocked.');
      return;
    }

    // Pause movement immediately while user decides
    _controller.pauseGpsTracking();

    RouteModel? route;
    try {
      route = await _routingService.getRouteToPOI(
        startX: _controller.tracker.currentX,
        startY: _controller.tracker.currentY,
        startLevel: _controller.currentLevel,
        poiId: poi.id,
        avoidStairs: false,
      );
    } catch (e) {}

    if (!mounted) {
      _controller.resumeGpsTracking();
      return;
    }

    // Show the green preview route on the map
    if (route != null) {
      setState(() => _previewRoute = route);
    }

    POIDetailsSheet.show(
      context,
      poi: poi,
      route: route,
      allNodes: widget.nodes,
      onNavigate: () {
        if (route != null) {
          // Switch to new navigation
          setState(() => _previewRoute = null);
          _controller.endNavigation().then((_) {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => NavigationPage(
                    route: route!,
                    destination: poi,
                    nodes: widget.nodes,
                    initialX: _controller.tracker.currentX,
                    initialY: _controller.tracker.currentY,
                    initialLevel: _controller.currentLevel,
                  ),
                ),
              );
            }
          });
        }
      },
    ).whenComplete(() {
      // Sheet dismissed without navigating — clear preview and resume original
      if (mounted) {
        setState(() => _previewRoute = null);
        _controller.resumeGpsTracking();
      }
    });
  }

  // FIX 5: consistent zero-padding for both hours and minutes
  String _getArrivalTime() {
    final now = DateTime.now();
    final arrivalTime = now.add(
      Duration(seconds: _controller.remainingTimeSeconds),
    );
    return '${arrivalTime.hour.toString().padLeft(2, '0')}:${arrivalTime.minute.toString().padLeft(2, '0')}';
  }

  void _handleManualMapInteraction(String source) {
    // Cancel any existing idle timer
    _idleTimer?.cancel();

    if (_isFollowingUser) {
      setState(() {
        _isFollowingUser = false;
      });
    }

    // Start a new 5-second timer to auto-recenter
    _idleTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !_isFollowingUser) {
        setState(() {
          _isFollowingUser = true;
        });
        _followUserPosition();
      }
    });
  }

  void _onCompassPressed() {
    _handleManualMapInteraction("Compass Press");
  }

  String _routeSignature(RouteModel route) {
    final ids = route.waypoints.map((w) => w.nodeId).join('>');
    return '${route.waypoints.length}|$ids';
  }

  @override
  Widget build(BuildContext context) {
    final tracker = _controller.tracker;

    final userPosition = LatLng(tracker.currentY, tracker.currentX);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _endNavigation();
      },
      // FIX 6: corrected Scaffold/body structure (Stack was misaligned in original)
      child: Scaffold(
        body: Stack(
          children: [
            // Mapa de fundo com rota destacada
            StadiumMapPage(
              key: ValueKey('nav-map-${_routeSignature(_controller.route)}'),
              highlightedRoute: _controller.route,
              highlightedPOI: widget.destination,
              mapController: _animatedMapController.mapController,
              isNavigating: true,
              isFollowingUser: _isFollowingUser,
              userPosition: userPosition,
              userHeading: _controller.heading,
              routeStartWaypointIndex: _controller.routeStartWaypointIndex,
              initialFloor: _controller.currentLevel,
              showHeatmap: _showHeatmap,
              isEmergency: widget.isEmergency,
              onTapPOI: widget.isEmergency ? null : _showSwitchDestinationSheet,
              onCompassPressed: _onCompassPressed,
              previewRoute: _previewRoute,
              onToggleNavigationHeatmap: () {
                setState(() {
                  _showHeatmap = !_showHeatmap;
                });
              },
              onRecenterNavigation: () {
                print(
                  '[NavigationPage] Center button pressed. Enabling follow mode.',
                );
                setState(() {
                  _isFollowingUser = true;
                });
                _followUserPosition();
              },
              navigationControlsBottomInset: _showReroutePopup
                  ? 360
                  : (_isBottomSheetExpanded ? 360 : 200),
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture) {
                  _handleManualMapInteraction("Gesture");
                }
              },
            ),

            // Header com instrução de navegação (topo) — IgnorePointer para o mapa receber toques
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: NavigationHeader(
                  instruction: _controller.currentInstruction,
                  isEmergency: widget.isEmergency,
                ),
              ),
            ),

            // Bottom sheet com informações (Hide when popup is visible)
            if (!_showReroutePopup)
              Positioned(
                left: 24,
                right: 24,
                bottom: 24,
                child: NavigationBottomSheet(
                  arrivalTime: _getArrivalTime(),
                  remainingTime: _controller.formattedRemainingTime,
                  remainingDistance: _controller.formattedRemainingDistance,
                  destination: widget.destination,
                  onEndRoute: _endNavigation,
                  isEmergency: widget.isEmergency,
                  onExpansionChanged: (expanded) {
                    setState(() {
                      _isBottomSheetExpanded = expanded;
                    });
                  },
                ),
              ),

            // Reroute Popup
            if (_showReroutePopup && _rerouteEvent != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ReroutePopup(
                  arrivalTime: _rerouteEvent!.arrivalTime,
                  duration: _rerouteEvent!.duration,
                  distance: _rerouteEvent!.distance,
                  locationName: _rerouteEvent!.locationName,
                  onAccept: () async {
                    String capturedNewDestinationId =
                        _rerouteEvent?.newDestinationId ?? '';
                    if (capturedNewDestinationId.isEmpty) {
                      capturedNewDestinationId = widget.destination.id;
                    }

                    String? capturedCategory = _rerouteEvent?.category;
                    final originalCategory = widget.destination.category;

                    print('[NavigationPage] 🔍 Debug Reroute Values:');
                    print(
                      '  - Event Dest ID: "${_rerouteEvent?.newDestinationId}"',
                    );
                    print('  - Captured Dest ID: "$capturedNewDestinationId"');
                    print('  - Event Category: "${_rerouteEvent?.category}"');
                    print('  - Widget Dest Category: "$originalCategory"');

                    if ((capturedCategory == null ||
                            capturedCategory.isEmpty) &&
                        originalCategory.isNotEmpty) {
                      capturedCategory = originalCategory;
                      print(
                        '[NavigationPage] 📦 Using original destination category: $capturedCategory',
                      );
                    }

                    // FIX 7: simplified and corrected category normalisation
                    if (capturedCategory != null &&
                        capturedCategory.isNotEmpty) {
                      if (capturedCategory.toLowerCase() == 'wc') {
                        capturedCategory = 'WC';
                      } else {
                        capturedCategory =
                            capturedCategory[0].toUpperCase() +
                            capturedCategory.substring(1).toLowerCase();
                      }
                    }

                    print('  - Final Captured Category: "$capturedCategory"');

                    setState(() {
                      _showReroutePopup = false;
                    });

                    if (mounted) {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) =>
                            const Center(child: CircularProgressIndicator()),
                      );
                    }

                    try {
                      _controller.pauseGpsTracking();

                      final currentX = _controller.tracker.currentX;
                      final currentY = _controller.tracker.currentY;
                      final currentLevel = _controller.currentLevel;

                      RouteModel newRoute;

                      String? effectiveCategory = capturedCategory;
                      if ((effectiveCategory == null ||
                              effectiveCategory.isEmpty) &&
                          capturedNewDestinationId.contains('-')) {
                        effectiveCategory = capturedNewDestinationId
                            .split('-')
                            .first;
                        print(
                          '[NavigationPage] 📦 Extracted category from POI ID: $effectiveCategory',
                        );
                      }

                      if (effectiveCategory != null &&
                          effectiveCategory.isNotEmpty) {
                        print(
                          '[NavigationPage] 🔄 Requesting nearest $effectiveCategory from ($currentX, $currentY) level=$currentLevel',
                        );
                        newRoute = await _routingService
                            .getRouteToNearestCategory(
                              startX: currentX,
                              startY: currentY,
                              startLevel: currentLevel,
                              category: effectiveCategory,
                              avoidStairs: false,
                            );
                      } else {
                        print(
                          '[NavigationPage] 🔄 Requesting route to specific POI $capturedNewDestinationId',
                        );
                        newRoute = await _routingService.getRouteToPOI(
                          startX: currentX,
                          startY: currentY,
                          startLevel: currentLevel,
                          poiId: capturedNewDestinationId,
                          avoidStairs: false,
                        );
                      }

                      if (newRoute.path.isNotEmpty) {
                        final nodeIds = newRoute.path
                            .map((p) => p.nodeId)
                            .toList();
                        print(
                          '[NavigationPage] ✅ New route received with ${nodeIds.length} nodes',
                        );
                        if (mounted) {
                          Navigator.pop(context); // Dismiss loading dialog
                        }

                        _controller.applyNewRoute(nodeIds);

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Route updated successfully!"),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      print('[NavigationPage] ❌ Failed to get new route: $e');
                      if (mounted) {
                        Navigator.pop(context); // Dismiss loading dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Failed to recalculate route: $e"),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  onDecline: () {
                    setState(() {
                      _showReroutePopup = false;
                    });
                  },
                ),
              ),


          ],
        ),
      ),
    );
  }
}
