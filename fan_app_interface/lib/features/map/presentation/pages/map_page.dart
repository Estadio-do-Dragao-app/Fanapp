import 'package:flutter/material.dart';
import '../stadium_map_page.dart';

/// MapPage implementation with functional stadium map
class MapPage extends StatefulWidget {
  final bool showHeatmap;
  final VoidCallback? onHeatmapConnectionError;
  final VoidCallback? onHeatmapConnectionSuccess;

  const MapPage({
    Key? key,
    this.showHeatmap = false,
    this.onHeatmapConnectionError,
    this.onHeatmapConnectionSuccess,
  }) : super(key: key);

  @override
  State<MapPage> createState() => MapPageState();
}

class MapPageState extends State<MapPage> {
  final GlobalKey<StadiumMapPageState> _stadiumMapKey =
      GlobalKey<StadiumMapPageState>();

  // Public method to zoom to POI
  void zoomToPOI(poi) {
    _stadiumMapKey.currentState?.zoomToPOI(poi);
  }

  @override
  Widget build(BuildContext context) {
    return StadiumMapPage(
      key: _stadiumMapKey,
      showHeatmap: widget.showHeatmap,
      onHeatmapConnectionError: widget.onHeatmapConnectionError,
      onHeatmapConnectionSuccess: widget.onHeatmapConnectionSuccess,
    );
  }
}
