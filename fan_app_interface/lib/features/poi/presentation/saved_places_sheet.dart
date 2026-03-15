import 'package:flutter/material.dart';
import '../../map/data/models/poi_model.dart';
import '../../../core/utils/poi_style.dart';
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
    final screenHeight = MediaQuery.sizeOf(context).height;
    final emptyInitialChildSize = (300 / screenHeight).clamp(0.3, 0.45);
    final emptyMinChildSize = (220 / screenHeight).clamp(0.2, 0.35);

    return DraggableScrollableSheet(
      initialChildSize: _savedPlaces.isEmpty ? emptyInitialChildSize : 0.6,
      minChildSize: _savedPlaces.isEmpty ? emptyMinChildSize : 0.2,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return SafeArea(
          top: false,
          child: Container(
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
                      ? LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight - 48,
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.star_border,
                                      color: Colors.white54,
                                      size: 48,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Ainda não guardou nenhum lugar.',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 16,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
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
                                    POIStyle.getIcon(
                                      poi.category,
                                      name: poi.name,
                                    ),
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
          ),
        );
      },
    );
  }
}
