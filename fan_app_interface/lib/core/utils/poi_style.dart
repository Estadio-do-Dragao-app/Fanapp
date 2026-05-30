import 'package:flutter/material.dart';

/// Centralized POI styling utility.
/// All icon and color mappings for POI categories live here.
/// Change once → reflected everywhere in the app.
///
/// Active categories: restroom/wc, food, restaurant, cafe, bar,
///   emergency_exit, first_aid, information, stairs, ramp,
///   entrance, library, parking
class POIStyle {
  POIStyle._(); // prevent instantiation

  // ─── Icons ────────────────────────────────────────────────

  static IconData getIcon(String category, {String? name}) =>
      getCategoryIcon(category);

  static IconData getCategoryIcon(String categoryId) {
    switch (categoryId.toLowerCase()) {
      case 'restroom':
      case 'wc':
        return Icons.wc;
      case 'cgd':
      case 'atm':
        return Icons.account_balance;
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
        return Icons.info_outline;
      case 'departments':
      case 'department':
      case 'departamento':
        return Icons.house;
      case 'stairs':
        return Icons.stairs;
      case 'ramp':
        return Icons.accessible_forward;
      case 'entrance':
        return Icons.login;
      case 'library':
        return Icons.local_library;
      case 'parking':
        return Icons.local_parking;
      default:
        return Icons.place;
    }
  }

  // ─── Colors ───────────────────────────────────────────────

  /// Pastel palette: strong hue, high lightness — not washed out.
  static Color getColor(String category, {String? name}) {
    switch (category.toLowerCase()) {
      case 'restroom':
      case 'wc':
        return const Color(0xFF42A5F5); // vivid sky blue

      case 'cgd':
      case 'atm':
        return const Color(0xFF1E88E5); // CGD blue

      case 'food':
      case 'restaurant':
        return const Color(0xFFFF8A65); // coral orange

      case 'cafe':
        return const Color(0xFFA1887F); // warm coffee brown

      case 'bar':
        return const Color(0xFFAB47BC); // bright purple

      case 'emergency_exit':
        return const Color(0xFFEF5350); // clear red

      case 'first_aid':
        return const Color(0xFF26A69A); // teal green

      case 'information':
      case 'departments':
      case 'department':
      case 'departamento':
        return const Color(0xFF29B6F6); // bright cyan-blue

      case 'entrance':
        return const Color(0xFF66BB6A); // fresh green

      case 'stairs':
      case 'ramp':
        return const Color(0xFFFFCA28); // bright amber

      case 'library':
        return const Color(0xFF8D6E63); // rich brown

      case 'parking':
        return const Color(0xFF78909C); // slate blue-grey

      default:
        return const Color(0xFF757575); // medium grey
    }
  }
}
