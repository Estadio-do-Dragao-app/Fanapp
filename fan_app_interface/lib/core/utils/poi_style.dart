import 'package:flutter/material.dart';

/// Centralized POI styling utility.
/// All icon and color mappings for POI categories live here.
/// Change once → reflected everywhere in the app.
class POIStyle {
  POIStyle._(); // prevent instantiation

  // ─── Icons ───────────────────────────────────────────────

  /// Returns the icon for a POI, considering both category and name.
  /// Use this when you have access to the full POI model.
  static IconData getIcon(String category, {String? name}) {
    // Name-based overrides (highest priority)
    if (name != null) {
      final lowerName = name.toLowerCase();
      if (lowerName.contains('cgd')) return Icons.atm;
    }

    switch (category.toLowerCase()) {
      case 'atm':
      case 'cgd':
        return Icons.atm;
      case 'departamento':
      case 'department':
        return Icons.home_work_rounded;
      case 'restroom':
      case 'wc':
        return Icons.wc;
      case 'food':
      case 'restaurant':
        return Icons.restaurant;
      case 'cafe':
        return Icons.local_cafe;
      case 'bar':
        return Icons.local_bar;
      case 'emergency_exit':
        return Icons.exit_to_app;
      case 'first_aid':
        return Icons.local_hospital;
      case 'information':
        return Icons.info;
      case 'gate':
        return Icons.door_front_door;
      case 'merchandise':
      case 'shop':
      case 'store':
        return Icons.store;
      case 'stairs':
        return Icons.stairs;
      case 'ramp':
        return Icons.accessible;
      case 'entrance':
        return Icons.login;
      case 'seat':
        return Icons.event_seat;
      case 'library':
        return Icons.local_library;
      case 'parking':
        return Icons.local_parking;
      // case 'ticket':
      //   return Icons.local_activity; // Ticket feature temporarily disabled
      default:
        return Icons.place;
    }
  }

  /// Simpler version for navbar / destination-selection contexts
  /// where only the category ID string is available.
  static IconData getCategoryIcon(String categoryId) {
    return getIcon(categoryId);
  }

  // ─── Colors ──────────────────────────────────────────────

  /// Returns marker background color for a POI on the map.
  static Color getColor(String category, {String? name}) {
    // Name-based overrides
    if (name != null) {
      final lowerName = name.toLowerCase();
      if (lowerName.contains('cgd')) return Colors.blue.shade800;
    }

    switch (category.toLowerCase()) {
      case 'atm':
      case 'cgd':
        return Colors.blue.shade800;
      case 'departamento':
      case 'department':
        return Colors.indigo.shade600;
      case 'restroom':
      case 'wc':
        return Colors.blue.shade700;
      case 'food':
      case 'cafe':
      case 'restaurant':
        return Colors.orange.shade700;
      case 'bar':
        return Colors.purple.shade700;
      case 'emergency_exit':
        return Colors.red.shade700;
      case 'first_aid':
        return Colors.green.shade700;
      case 'information':
        return Colors.cyan.shade700;
      case 'gate':
        return Colors.indigo.shade700;
      case 'merchandise':
      case 'shop':
      case 'store':
        return Colors.pink.shade700;
      case 'stairs':
      case 'ramp':
        return Colors.amber.shade700;
      case 'entrance':
        return Colors.teal.shade700;
      case 'seat':
        return Colors.green.shade700;
      case 'library':
        return Colors.brown.shade700;
      case 'parking':
        return Colors.blueGrey.shade700;
      default:
        return Colors.grey.shade700;
    }
  }
}
