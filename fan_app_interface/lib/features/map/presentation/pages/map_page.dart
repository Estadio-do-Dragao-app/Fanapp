import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../fan_map_page.dart';

/// MapPage implementation with functional stadium map
class MapPage extends StatefulWidget {
  final bool showHeatmap;
  final VoidCallback? onHeatmapConnectionError;
  final VoidCallback? onHeatmapConnectionSuccess;
  final ValueChanged<int>? onFloorChanged;
  final MapController? mapController;
  final int currentFloor;
  final bool avoidStairs;
  final ValueChanged<bool>? onPOIPanelChanged;

  const MapPage({
    super.key,
    this.mapController,
    this.showHeatmap = false,
    this.onHeatmapConnectionError,
    this.onHeatmapConnectionSuccess,
    this.onFloorChanged,
    this.currentFloor = 0,
    this.avoidStairs = false,
    this.onPOIPanelChanged,
  });

  @override
  State<MapPage> createState() => MapPageState();
}

class MapPageState extends State<MapPage> {
  final GlobalKey<FanMapPageState> _stadiumMapKey =
      GlobalKey<FanMapPageState>();

  // Public method to zoom to POI
  void zoomToPOI(poi) {
    _stadiumMapKey.currentState?.zoomToPOI(poi);
  }

  // Public method to open POI panel and preview route
  void openPOIDetails(poi) {
    _stadiumMapKey.currentState?.openPOIDetails(poi);
  }

  void reloadUserPosition() {
    _stadiumMapKey.currentState?.loadUserPosition();
  }

  void reloadMapData() {
    _stadiumMapKey.currentState?.reloadMapData();
  }

  @override
  Widget build(BuildContext context) {
    return FanMapPage(
      key: _stadiumMapKey,
      showHeatmap: widget.showHeatmap,
      onHeatmapConnectionError: widget.onHeatmapConnectionError,
      onHeatmapConnectionSuccess: widget.onHeatmapConnectionSuccess,
      onFloorChanged: widget.onFloorChanged,
      initialFloor: widget.currentFloor,
      avoidStairs: widget.avoidStairs,
      onPOIPanelChanged: widget.onPOIPanelChanged,
    );
  }
}
