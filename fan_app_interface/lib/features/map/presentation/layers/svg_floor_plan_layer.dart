import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

/// Camada que renderiza uma planta SVG como fundo do mapa.
///
/// Usa o sistema de coordenadas CrsSimple: o SVG (800x600 viewBox)
/// é posicionado de modo a cobrir toda a área de coordenadas do mapa.
class SvgFloorPlanLayer extends StatelessWidget {
  /// Asset path do SVG (ex: 'assets/images/PLANTA1.svg')
  final String svgAsset;

  /// Bounds do SVG em coordenadas do mapa (CrsSimple: LatLng(y, x))
  /// Por defeito: cobre a viewBox 0-459 x 0-465
  final LatLng topLeft;
  final LatLng bottomRight;

  const SvgFloorPlanLayer({
    super.key,
    required this.svgAsset,
    this.topLeft = const LatLng(
      46.5,
      0,
    ), // SVG y=0 (topo) → lat = (465 - 0)/10 = 46.5
    this.bottomRight = const LatLng(
      0,
      45.9,
    ), // SVG y=465 (fundo) → lat = 0, lng = 459/10 = 45.9
  });

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);

    // Projetar os cantos do SVG para pixels no ecrã
    final topLeftPixel = camera.latLngToScreenPoint(topLeft);
    final bottomRightPixel = camera.latLngToScreenPoint(bottomRight);

    // Calcular tamanho e posição em pixels usando min/abs para evitar tamanhos negativos
    final left = math.min(topLeftPixel.x, bottomRightPixel.x);
    final top = math.min(topLeftPixel.y, bottomRightPixel.y);
    final width = (bottomRightPixel.x - topLeftPixel.x).abs();
    final height = (bottomRightPixel.y - topLeftPixel.y).abs();

    print(
      '[SvgFloorPlan] asset=$svgAsset topLeft=($left, $top) size=($width x $height) zoom=${camera.zoom}',
    );

    // Não renderizar se fora do ecrã ou tamanho inválido
    if (width <= 0 || height <= 0) {
      print(
        '[SvgFloorPlan] SKIPPED: width=$width height=$height (invalid size)',
      );
      return const SizedBox.shrink();
    }

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: IgnorePointer(child: SvgPicture.asset(svgAsset, fit: BoxFit.fill)),
    );
  }
}
