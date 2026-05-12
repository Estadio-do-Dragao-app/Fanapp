import 'package:flutter/material.dart';
import 'package:fan_app_interface/core/widgets/category_buttons.dart';
import 'package:fan_app_interface/features/poi/presentation/destination_selection.dart';
import 'package:fan_app_interface/l10n/app_localizations.dart';

import 'package:fan_app_interface/core/widgets/poi_icon.dart';

/// Simple MapPage implementation that shows a placeholder 'map' area and a
/// horizontal row of category buttons overlayed at the top.
class Navbar extends StatefulWidget {
  final VoidCallback? onNavigationEnd;
  final bool avoidStairs;
  final Widget? filterButton;

  const Navbar({
    Key? key,
    this.onNavigationEnd,
    this.avoidStairs = false,
    this.filterButton,
  }) : super(key: key);

  @override
  State<Navbar> createState() => _NavbarState();
}

class _NavbarState extends State<Navbar> {
  final List<String> categoryIds = ['food', 'first_aid', 'wc', 'poi'];
  int selected = 0;

  Future<void> _handleCategorySelect(
    int i,
    AppLocalizations localizations,
  ) async {
    setState(() => selected = i);

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            DestinationSelectionPage(
              categoryId: categoryIds[i],
              avoidStairs: widget.avoidStairs,
            ),
        transitionsBuilder: _buildSlideTransition,
      ),
    ).then((_) {
      if (mounted) widget.onNavigationEnd?.call();
    });
  }
  Widget _buildSlideTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    const begin = Offset(0.0, 1.0);
    const end = Offset.zero;
    const curve = Curves.easeInOut;
    final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
    final offsetAnimation = animation.drive(tween);
    return SlideTransition(position: offsetAnimation, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final categories = [
      localizations.food,
      localizations.firstAid,
      localizations.wc,
      localizations.information,
    ];

    return Stack(
      children: [
        // IgnorePointer so the map behind the gradient can receive touches
        // Positioned.fill ensures the gradient matches the Stack's content size
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.fromARGB(255, 110, 119, 207),
                    Color.fromARGB(255, 110, 119, 207).withOpacity(0.9),
                    Color.fromARGB(255, 110, 119, 207).withOpacity(0.7),
                    Color.fromARGB(255, 110, 119, 207).withOpacity(0.4),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ),

        // Top overlay: category buttons inside SafeArea
        // Align constrains this to only the top — otherwise SafeArea fills
        // the entire Stack and swallows map touches below the buttons.
        Align(
          alignment: Alignment.topLeft,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.whereToQuestion,
                    style: const TextStyle(
                      fontSize: 32,
                      fontFamily: 'Gabarito',
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.left,
                  ),
                  const SizedBox(height: 16),
                  CategoryButtons(
                    labels: categories,
                    selectedIndex: selected,
                    onSelect: (i) => _handleCategorySelect(i, localizations),
                    iconBuilder: (label) {
                      // Map translated label back to category ID
                      String catId;
                      if (label == localizations.food) {
                        catId = 'food';
                      } else if (label == localizations.firstAid) {
                        catId = 'first_aid';
                      } else if (label == localizations.wc) {
                        catId = 'wc';
                      } else if (label == localizations.information) {
                        catId = 'department';
                      } else {
                        catId = label;
                      }
                      return POIIcon(
                        categoryId: catId,
                        color: Colors.black,
                        size: 24,
                      );
                    },
                  ),
                  if (widget.filterButton != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: widget.filterButton!,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
