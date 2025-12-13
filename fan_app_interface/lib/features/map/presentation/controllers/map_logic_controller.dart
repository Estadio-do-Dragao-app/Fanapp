import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Controller to decouple logic from the UI widget.
/// Manages user position, navigation state, and map interactions.
class MapLogicController extends ChangeNotifier {
  final MapController mapController;
  
  // User state
  double _userX = 0.0;
  double _userY = 0.0;
  String _userNodeId = 'N1';
  bool _isFollowingUser = false;
  
  // Navigation state
  bool _isNavigating = false;
  
  // Callbacks for UI updates if needed specifically (beyond notifyListeners)
  Function(double x, double y)? onUserMoved;

  MapLogicController({
    MapController? mapController,
  }) : mapController = mapController ?? MapController();

  double get userX => _userX;
  double get userY => _userY;
  String get userNodeId => _userNodeId;
  bool get isFollowingUser => _isFollowingUser;
  bool get isNavigating => _isNavigating;
  
  LatLng get userPositionLatLng => LatLng(_userY, _userX);

  void setUserPosition(double x, double y, {String? nodeId}) {
    _userX = x;
    _userY = y;
    if (nodeId != null) {
      _userNodeId = nodeId;
    }
    
    if (_isFollowingUser) {
      centerOnUser();
    }
    
    onUserMoved?.call(x, y);
    notifyListeners();
  }

  void moveUser(double dx, double dy) {
    setUserPosition(_userX + dx, _userY + dy);
  }

  void centerOnUser() {
    // Use current zoom, but ensure it's reasonable for visibility
    double zoom = mapController.camera.zoom;
    // Clamp to reasonable range for 0-200 coordinate system
    if (zoom < 0.5) zoom = 1.0;
    if (zoom > 3.0) zoom = 2.0;
    mapController.move(userPositionLatLng, zoom);
  }

  void toggleFollowUser() {
    _isFollowingUser = !_isFollowingUser;
    if (_isFollowingUser) {
      centerOnUser();
    }
    notifyListeners();
  }
  
  void startNavigation() {
    _isNavigating = true;
    _isFollowingUser = true;
    centerOnUser();
    notifyListeners();
  }
  
  void stopNavigation() {
    _isNavigating = false;
    _isFollowingUser = false;
    notifyListeners();
  }
  
  void zoomIn() {
    mapController.move(mapController.camera.center, mapController.camera.zoom + 1);
  }
  
  void zoomOut() {
    mapController.move(mapController.camera.center, mapController.camera.zoom - 1);
  }
}
