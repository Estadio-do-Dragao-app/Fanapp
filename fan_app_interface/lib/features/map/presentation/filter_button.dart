import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';

/// Filter button with expandable menu for map options
class FilterButton extends StatefulWidget {
  final bool showHeatmap;
  final bool isHeatmapAvailable;
  final ValueChanged<bool> onHeatmapChanged;
  final int currentFloor;
  final ValueChanged<int> onFloorChanged;
  final List<int> availableFloors;
  final bool avoidStairs;
  final ValueChanged<bool> onAvoidStairsChanged;

  const FilterButton({
    Key? key,
    required this.showHeatmap,
    this.isHeatmapAvailable = true,
    required this.onHeatmapChanged,
    this.currentFloor = 0,
    required this.onFloorChanged,
    this.availableFloors = const [0, 1],
    this.avoidStairs = false,
    required this.onAvoidStairsChanged,
  }) : super(key: key);

  @override
  State<FilterButton> createState() => _FilterButtonState();
}

class _FilterButtonState extends State<FilterButton>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Filter button
        GestureDetector(
          onTap: _toggleExpanded,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _isExpanded ? const Color(0xFF161A3E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.tune,
              color: _isExpanded ? Colors.white : const Color(0xFF161A3E),
              size: 24,
            ),
          ),
        ),

        // Expanded menu
        if (_isExpanded)
          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF161A3E),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.filter_alt,
                        color: Colors.white.withOpacity(0.8),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)!.filter,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Gabarito',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 12),

                  // Floor selector
                  _buildFloorSelector(context),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white24, height: 1),

                  // Accessibility toggle
                  const SizedBox(height: 12),
                  _buildAccessibilityToggle(context),

                  const SizedBox(height: 12),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 12),

                  // Heat map toggle
                  _buildHeatmapToggle(context),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFloorSelector(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.layers, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        SizedBox(
          width: 120,
          child: Text(
            AppLocalizations.of(context)!.floor,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Gabarito',
              fontSize: 14,
            ),
          ),
        ),
        // Floor buttons
        ...widget.availableFloors.map((floor) {
          final isSelected = floor == widget.currentFloor;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => widget.onFloorChanged(floor),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF929AD4)
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF929AD4)
                        : Colors.white.withOpacity(0.3),
                  ),
                ),
                child: Center(
                  child: Text(
                    '$floor',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontFamily: 'Gabarito',
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildHeatmapToggle(BuildContext context) {
    final bool isAvailable = widget.isHeatmapAvailable;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.whatshot,
              color: isAvailable ? Colors.white : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 120,
              child: Text(
                AppLocalizations.of(context)!.heatmap,
                style: TextStyle(
                  color: isAvailable ? Colors.white : Colors.grey[600],
                  fontFamily: 'Gabarito',
                  fontSize: 14,
                ),
              ),
            ),
            SizedBox(
              height: 24,
              child: Switch(
                value: widget.showHeatmap,
                onChanged: isAvailable ? widget.onHeatmapChanged : null,
                activeColor: const Color(0xFF929AD4),
                activeTrackColor: const Color(0xFF929AD4).withOpacity(0.5),
                inactiveThumbColor: isAvailable
                    ? Colors.grey[400]
                    : Colors.grey[700],
                inactiveTrackColor: isAvailable
                    ? Colors.grey[600]
                    : Colors.grey[800],
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        // Error message when unavailable
        if (!isAvailable)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange[300],
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  AppLocalizations.of(context)!.connectionFailed,
                  style: TextStyle(
                    color: Colors.orange[300],
                    fontFamily: 'Gabarito',
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAccessibilityToggle(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.accessible, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        SizedBox(
          width: 120,
          child: Text(
            AppLocalizations.of(context)!.accessibility,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Gabarito',
              fontSize: 14,
            ),
          ),
        ),
        SizedBox(
          height: 24,
          child: Switch(
            value: widget.avoidStairs,
            onChanged: widget.onAvoidStairsChanged,
            activeColor: const Color(0xFF929AD4),
            activeTrackColor: const Color(0xFF929AD4).withOpacity(0.5),
            inactiveThumbColor: Colors.grey[400],
            inactiveTrackColor: Colors.grey[600],
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }
}
