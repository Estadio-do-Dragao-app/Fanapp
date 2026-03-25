import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CachedTileProvider extends TileProvider {
  static CacheManager? _mapCacheManager;

  CachedTileProvider() {
    _mapCacheManager ??= CacheManager(
      Config(
        'MapTilesCache',
        stalePeriod: const Duration(days: 14),
        maxNrOfCacheObjects: 5000,
      ),
    );
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return CachedNetworkImageProvider(
      getTileUrl(coordinates, options),
      cacheManager: _mapCacheManager,
      errorListener: (dynamic error) {
        debugPrint('Cache/Network Error loading tile: $error');
      },
    );
  }
}
