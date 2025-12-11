import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../data/models/node_model.dart';
import '../../data/models/edge_model.dart';
import '../../utils/map_geometry_helper.dart';

class FloorPlanLayer extends StatelessWidget {
  final List<EdgeModel> edges;
  final List<NodeModel> nodes;
  final int currentLevel;
  final LatLng Function(double x, double y) converter;

  const FloorPlanLayer({
    super.key,
    required this.edges,
    required this.nodes,
    required this.currentLevel,
    required this.converter,
  });

  @override
  Widget build(BuildContext context) {
    // Convert List<NodeModel> to Map for O(1) access
    final nodesMap = {for (var n in nodes) n.id: n};

    // Generate polygons
    final polygons = MapGeometryHelper.generateFloorPlan(
      edges,
      nodesMap,
      currentLevel,
      converter,
    );

    return PolygonLayer(polygons: polygons);
  }
}
