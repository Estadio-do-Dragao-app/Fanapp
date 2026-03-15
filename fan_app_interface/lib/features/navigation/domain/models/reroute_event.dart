class RerouteEvent {
  final String arrivalTime;
  final String duration;
  final int distance;
  final String locationName; // e.g. "WC 2"
  final String newDestinationId;
  final String? category; // POI category for nearest_category lookup (e.g., "WC", "Food")
  final List<String>? newRouteIds; // List of node IDs for the new route
  final String
  reason; // e.g. "Less queue" - maybe use enum later, string for now

  RerouteEvent({
    required this.arrivalTime,
    required this.duration,
    required this.distance,
    required this.locationName,
    required this.newDestinationId,
    required this.reason,
    this.category,
    this.newRouteIds,
  });
}
