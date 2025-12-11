import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../data/models/node_model.dart';
import '../data/models/edge_model.dart';

/// Helper class to generate visual geometry for the map
class MapGeometryHelper {
  /// Defines the width of corridors in meters (visual)
  static const double corridorWidth = 5.0;

  /// Generates polygons for corridors based on edges
  /// Uses a basic buffer algorithm (expands line into rectangle)
  static List<Polygon> generateFloorPlan(
    List<EdgeModel> edges,
    Map<String, NodeModel> nodesMap,
    int level,
    LatLng Function(double x, double y) converter,
  ) {
    List<Polygon> polygons = [];

    for (var edge in edges) {
      final fromNode = nodesMap[edge.fromId];
      final toNode = nodesMap[edge.toId];

      if (fromNode == null || toNode == null) continue;

      // Only draw edges on the requested level
      // If nodes are on different levels (stairs), draw on both (or handle specially)
      // Strict Mode: Only draw edges where BOTH nodes are on the current level
      // This prevents "stairs" edges from looking weird or causing overlaps
      if (fromNode.level != level || toNode.level != level) continue;

      // Calculate direction vector
      final dx = toNode.x - fromNode.x;
      final dy = toNode.y - fromNode.y;
      final length = sqrt(dx * dx + dy * dy);

      if (length == 0) continue;

      // Normalize vector
      final ux = dx / length;
      final uy = dy / length;

      // Perpendicular vector (-y, x)
      final px = -uy;
      final py = ux;

      // Half width offset
      final halfWidth = corridorWidth / 2;

      // Calculate 4 corners of the rectangle
      final p1x = fromNode.x + px * halfWidth;
      final p1y = fromNode.y + py * halfWidth;

      final p2x = toNode.x + px * halfWidth;
      final p2y = toNode.y + py * halfWidth;

      final p3x = toNode.x - px * halfWidth;
      final p3y = toNode.y - py * halfWidth;

      final p4x = fromNode.x - px * halfWidth;
      final p4y = fromNode.y - py * halfWidth;

      polygons.add(
        Polygon(
          points: [
            converter(p1x, p1y),
            converter(p2x, p2y),
            converter(p3x, p3y),
            converter(p4x, p4y),
          ],
          color: const Color(
            0xFFE0E0E0,
          ).withOpacity(0.5), // Light grey for blueprint
          borderStrokeWidth: 1,
          borderColor: Colors.grey, // Darker grey for border
          isFilled: true,
        ),
      );
    }

    return polygons;
  }
}
