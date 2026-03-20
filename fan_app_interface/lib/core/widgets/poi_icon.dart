import 'package:flutter/material.dart';
import '../../core/utils/poi_style.dart';
import 'package:fan_app_interface/l10n/app_localizations.dart';

/// Renders the correct icon for a POI category.
/// For restrooms/WC it shows bold "WC" text instead of an icon,
/// making it consistent in size with every other category icon.
class POIIcon extends StatelessWidget {
  final String categoryId;
  final double size;
  final Color color;

  const POIIcon({
    Key? key,
    required this.categoryId,
    this.size = 24.0,
    this.color = Colors.white,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isWC = categoryId.toLowerCase() == 'wc' ||
        categoryId.toLowerCase() == 'restroom';

    if (isWC) {
      // Use a slightly wider box so "WC" always fits at any size.
      return SizedBox(
        width: size * 1.2,
        height: size,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Text(
            AppLocalizations.of(context)?.wc ?? 'WC',
            style: TextStyle(
              color: color,
              fontSize: size,
              fontWeight: FontWeight.w900,
              height: 1.0,
              letterSpacing: -1,
            ),
          ),
        ),
      );
    }

    return Icon(
      POIStyle.getCategoryIcon(categoryId),
      color: color,
      size: size,
    );
  }
}
