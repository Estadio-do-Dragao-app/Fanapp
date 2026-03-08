import 'package:flutter/material.dart';
import '../../map/data/models/poi_model.dart';
import '../../map/data/services/saved_places_service.dart';

class SavedPlacesSheet extends StatefulWidget {
  final Function(POIModel poi) onPOISelected;

  const SavedPlacesSheet({Key? key, required this.onPOISelected})
    : super(key: key);

  static Future<void> show(
    BuildContext context, {
    required Function(POIModel poi) onPOISelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SavedPlacesSheet(onPOISelected: onPOISelected),
    );
  }

  @override
  State<SavedPlacesSheet> createState() => _SavedPlacesSheetState();
}

class _SavedPlacesSheetState extends State<SavedPlacesSheet> {
  List<POIModel> _savedPlaces = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedPlaces();
  }

  Future<void> _loadSavedPlaces() async {
    final places = await SavedPlacesService.getSavedPlaces();
    if (mounted) {
      setState(() {
        _savedPlaces = places;
        _isLoading = false;
      });
    }
  }

  Future<void> _removePlace(POIModel poi) async {
    await SavedPlacesService.removePlace(poi.id);
    _loadSavedPlaces();
  }

  @override
  Widget build(BuildContext context) {
    // Assuming localizations.savedPlaces doesn't exist yet, we'll use a hardcoded fallback
    // or you can add it to app_en.arb / app_pt.arb later.
    final title =
        'Favoritos'; // Replace with localizations.savedPlaces if available

    return DraggableScrollableSheet(
      initialChildSize: _savedPlaces.isEmpty ? 0.3 : 0.6,
      minChildSize: 0.2,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF161A3E), // Matching dark theme
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Gabarito',
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : _savedPlaces.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_border,
                                color: Colors.white54,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Ainda não guardou nenhum lugar.',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        itemCount: _savedPlaces.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final poi = _savedPlaces[index];
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: const Color(
                                  0xFF929AD4,
                                ).withValues(alpha: 0.2),
                                child: Icon(
                                  _getIconForCategory(poi.category),
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                poi.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Gabarito',
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white54,
                                ),
                                onPressed: () => _removePlace(poi),
                              ),
                              onTap: () {
                                Navigator.pop(context); // Close sheet
                                widget.onPOISelected(poi);
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'wc':
        return Icons.wc;
      case 'food':
      case 'restaurant':
      case 'bar':
      case 'bar_p':
        return Icons.fastfood;
      case 'store':
      case 'shop':
        return Icons.store;
      case 'ticket':
        return Icons.local_activity;
      case 'seat':
        return Icons.event_seat;
      default:
        return Icons.place;
    }
  }
}
