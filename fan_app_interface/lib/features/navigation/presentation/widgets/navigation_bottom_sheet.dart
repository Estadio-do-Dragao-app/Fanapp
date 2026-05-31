import 'package:flutter/material.dart';
import 'package:fan_app_interface/l10n/app_localizations.dart';
import '../../../map/data/models/poi_model.dart';

/// Bottom sheet expansível com informações de navegação
/// Estado normal (compacto) e expandido (com botão End Route)
class NavigationBottomSheet extends StatefulWidget {
  final String arrivalTime;
  final String remainingTime;
  final String remainingDistance;
  final POIModel destination;
  final VoidCallback onEndRoute;
  final ValueChanged<bool>? onExpansionChanged;
  final bool isEmergency;

  const NavigationBottomSheet({
    Key? key,
    required this.arrivalTime,
    required this.remainingTime,
    required this.remainingDistance,
    required this.destination,
    required this.onEndRoute,
    this.onExpansionChanged,
    this.isEmergency = false,
  }) : super(key: key);

  @override
  State<NavigationBottomSheet> createState() => _NavigationBottomSheetState();
}

class _NavigationBottomSheetState extends State<NavigationBottomSheet>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _heightAnimation;
  double _dragDeltaY = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _heightAnimation = Tween<double>(begin: 110, end: 280).animate(
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
    widget.onExpansionChanged?.call(_isExpanded);
  }

  void _setExpanded(bool expanded) {
    if (_isExpanded == expanded) return;
    _toggleExpanded();
  }

  void _onVerticalDragStart(DragStartDetails details) {
    _dragDeltaY = 0;
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    _dragDeltaY += details.primaryDelta ?? 0;
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -220) { _setExpanded(true); return; }
    if (velocity > 220) { _setExpanded(false); return; }
    if (_dragDeltaY < -18) { _setExpanded(true); }
    else if (_dragDeltaY > 18) { _setExpanded(false); }
  }

  // ─────────────────────────────────────────────────────────────────────────

  // Static decoration kept out of the AnimatedBuilder so we don't rebuild
  // BoxDecoration/BoxShadow at 60 fps while the height tween runs.
  static final BoxDecoration _sheetDecoration = BoxDecoration(
    color: const Color(0xFF1E1E3F),
    borderRadius: BorderRadius.circular(24),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.3),
        blurRadius: 16,
        offset: const Offset(0, -4),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    // Child is built once per expansion toggle (not per animation frame).
    final content = RepaintBoundary(
      child: _isExpanded
          ? _buildExpandedContent(loc)
          : _buildCollapsedContent(loc),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: _onVerticalDragStart,
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      // AnimatedBuilder rebuilds ONLY the SizedBox wrapper — decoration and
      // content are captured by closure and reused frame-to-frame.
      child: AnimatedBuilder(
        animation: _heightAnimation,
        builder: (context, child) {
          return SizedBox(
            height: _heightAnimation.value,
            child: child,
          );
        },
        child: DecoratedBox(
          decoration: _sheetDecoration,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: content,
          ),
        ),
      ),
    );
  }

  // ─── COLLAPSED: Column(center) ensures true vertical centering ───────────
  Widget _buildCollapsedContent(AppLocalizations loc) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // "^ MORE ^" hint — tappable
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleExpanded,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.keyboard_arrow_up, color: Colors.white54, size: 14),
                const SizedBox(width: 4),
                Text(
                  loc.more.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_up, color: Colors.white54, size: 14),
              ],
            ),
          ),
        ),
        // Info row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(child: _buildInfoColumn(loc.arrival, widget.arrivalTime, widget.isEmergency, CrossAxisAlignment.start)),
              Expanded(child: _buildInfoColumn(loc.time, widget.remainingTime, widget.isEmergency, CrossAxisAlignment.center)),
              Expanded(child: _buildInfoColumn(loc.distance, widget.remainingDistance, widget.isEmergency, CrossAxisAlignment.end)),
            ],
          ),
        ),
      ],
    );
  }

  // ─── EXPANDED: scrollable column with drag handle + destination + button ──
  Widget _buildExpandedContent(AppLocalizations loc) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle pill
          const SizedBox(height: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleExpanded,
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Info row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(child: _buildInfoColumn(loc.arrival, widget.arrivalTime, widget.isEmergency, CrossAxisAlignment.start)),
                Expanded(child: _buildInfoColumn(loc.time, widget.remainingTime, widget.isEmergency, CrossAxisAlignment.center)),
                Expanded(child: _buildInfoColumn(loc.distance, widget.remainingDistance, widget.isEmergency, CrossAxisAlignment.end)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Destination name + End Route button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  loc.destination,
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.destination.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: widget.onEndRoute,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.isEmergency
                          ? const Color(0xFFBD453D)
                          : const Color(0xFFE74C3C),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      loc.endRoute,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── INFO COLUMN ─────────────────────────────────────────────────────────
  Widget _buildInfoColumn(String label, String value, bool isEmergency,
      [CrossAxisAlignment alignment = CrossAxisAlignment.center]) {
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment == CrossAxisAlignment.start
              ? Alignment.centerLeft
              : alignment == CrossAxisAlignment.end
                  ? Alignment.centerRight
                  : Alignment.center,
          child: Text(
            value,
            style: TextStyle(
              color: isEmergency ? const Color(0xFFFF6B6B) : Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
        ),
      ],
    );
  }
}
