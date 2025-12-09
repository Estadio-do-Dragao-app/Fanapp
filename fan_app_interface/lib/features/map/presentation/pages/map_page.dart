import 'package:flutter/material.dart';
import '../stadium_map_page.dart';

/// MapPage implementation with functional stadium map
class MapPage extends StatefulWidget {
	const MapPage({Key? key}) : super(key: key);

	@override
	State<MapPage> createState() => MapPageState();
}

class MapPageState extends State<MapPage> {
	final GlobalKey<StadiumMapPageState> _stadiumMapKey = GlobalKey<StadiumMapPageState>();
	
	// Public method to zoom to POI
	void zoomToPOI(poi) {
		_stadiumMapKey.currentState?.zoomToPOI(poi);
	}

	@override
	Widget build(BuildContext context) {
    return StadiumMapPage(key: _stadiumMapKey);
  }
}
