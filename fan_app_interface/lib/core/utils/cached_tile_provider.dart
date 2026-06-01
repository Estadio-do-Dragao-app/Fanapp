import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;

// Singletons live for the app lifetime — shared across all page transitions.
// A single http.Client gives HTTP keep-alive and connection reuse across
// every concurrent tile request, which is the main win vs creating one per tile.
final BaseCacheManager _diskCache = CacheManager(
  Config(
    'MapTilesCache',
    stalePeriod: const Duration(days: 14),
    maxNrOfCacheObjects: 5000,
  ),
);

final http.Client _httpClient = http.Client();

class CachedTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return _TileImage(getTileUrl(coordinates, options));
  }
}

class _TileImage extends ImageProvider<_TileImage> {
  final String url;

  const _TileImage(this.url);

  @override
  Future<_TileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_TileImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _fetch(decode),
      scale: 1.0,
      informationCollector: () => [DiagnosticsProperty('URL', url)],
    );
  }

  Future<ui.Codec> _fetch(ImageDecoderCallback decode) async {
    Uint8List bytes;

    // Fast path: disk cache hit — no network needed
    final cached = await _diskCache.getFileFromCache(url);
    if (cached != null) {
      bytes = await cached.file.readAsBytes();
    } else {
      // Slow path: fetch from network using the shared keep-alive client
      final response = await _httpClient.get(
        Uri.parse(url),
        headers: const {'User-Agent': 'com.dragao.fanapp'},
      );
      if (response.statusCode != 200) {
        throw NetworkImageLoadException(
          statusCode: response.statusCode,
          uri: Uri.parse(url),
        );
      }
      bytes = response.bodyBytes;
      // Save to disk without blocking the render path
      _diskCache
          .putFile(url, bytes, maxAge: const Duration(days: 14))
          .ignore();
    }

    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) => other is _TileImage && url == other.url;

  @override
  int get hashCode => url.hashCode;
}
