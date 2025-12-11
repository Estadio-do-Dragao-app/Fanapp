import 'package:flutter/material.dart';

/// Filter button with expandable menu for map options
class FilterButton extends StatefulWidget {
  final bool showHeatmap;
  final ValueChanged<bool> onHeatmapChanged;

  const FilterButton({
    Key? key,
    required this.showHeatmap,
    required this.onHeatmapChanged,
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
                      const Text(
                        'Filter',
                        style: TextStyle(
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

                  // Heat map toggle
                  _buildToggleRow(
                    icon: Icons.whatshot,
                    label: 'Heat map',
                    value: widget.showHeatmap,
                    onChanged: widget.onHeatmapChanged,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Gabarito',
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          height: 24,
          child: Switch(
            value: value,
            onChanged: onChanged,
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
