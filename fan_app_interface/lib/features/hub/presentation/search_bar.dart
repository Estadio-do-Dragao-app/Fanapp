import 'package:flutter/material.dart';
import 'package:fan_app_interface/l10n/app_localizations.dart';
import '../../map/data/models/poi_model.dart';

import '../../map/data/services/map_service.dart';
import '../../../core/widgets/poi_icon.dart';

class SearchBarBottomSheet extends StatefulWidget {
  final Function(POIModel)? onPOISelected;
  final VoidCallback? onNavigationEnd;
  final bool avoidStairs;

  const SearchBarBottomSheet({
    Key? key,
    this.onPOISelected,
    this.onNavigationEnd,
    this.avoidStairs = false,
  }) : super(key: key);

  @override
  State<SearchBarBottomSheet> createState() => _SearchBarBottomSheetState();
}

class _SearchBarBottomSheetState extends State<SearchBarBottomSheet> {
  late TextEditingController _searchController;
  final MapService _mapService = MapService();

  List<POIModel> _allPOIs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadPOIs();
  }

  Future<void> _loadPOIs() async {
    try {
      final pois = await _mapService.getAllPOIs();
      if (!mounted) return;
      setState(() {
        _allPOIs = pois;
        _isLoading = false;
      });
    } catch (e) {
      print('[SearchBar] Erro ao carregar POIs: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Fecha a pesquisa e delega no callback o fluxo de abrir painel/rota
  Future<void> _showPOIDetails(POIModel poi) async {
    Navigator.pop(context);
    await Future.delayed(const Duration(milliseconds: 100));
    widget.onPOISelected?.call(poi);
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setModalState) {
        final query = _normalizeText(_searchController.text);
        final filteredPOIs = _buildFilteredPOIs(query);

        return FractionallySizedBox(
          heightFactor: 1.0,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1E2352), Color(0xFF161A3E)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Search Bar
                Container(
                  height: 68,
                  margin: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1A1E4B), Color(0xFF111639)],
                    ),
                    borderRadius: BorderRadius.circular(34),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.26),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, -1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 10),
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.09),
                          shape: BoxShape.circle,
                        ),
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
                          child: const Icon(
                            Icons.search,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Gabarito',
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.search,
                            hintStyle: const TextStyle(
                              color: Color(0xFF9BA3C8),
                              fontFamily: 'Gabarito',
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (value) {
                            setModalState(() {});
                          },
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                _searchController.clear();
                                setModalState(() {});
                              },
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
                // Results List
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: filteredPOIs.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final poi = filteredPOIs[index];
                            const textColor = Colors.white;

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
                                  child: POIIcon(
                                    categoryId: poi.category,
                                    color: textColor,
                                    size: 24,
                                  ),
                                ),
                                title: Text(
                                  poi.name,
                                  style: TextStyle(
                                    fontFamily: 'Gabarito',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                                trailing: Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: Colors.white54,
                                  size: 16,
                                ),
                                onTap: () {
                                  _showPOIDetails(poi);
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

  List<POIModel> _buildFilteredPOIs(String normalizedQuery) {
    if (normalizedQuery.isEmpty) return _allPOIs;

    final scored = _allPOIs
        .map((poi) => MapEntry(poi, _scorePOIMatch(poi, normalizedQuery)))
        .where((entry) => entry.value >= 0)
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return scored.map((entry) => entry.key).toList();
  }

  int _scorePOIMatch(POIModel poi, String query) {
    final candidates = _buildSearchCandidates(poi);

    if (candidates.contains(query)) return 0;
    if (candidates.any((c) => c.startsWith(query))) return 1;
    if (candidates.any((c) => c.contains(query))) return 2;

    return -1;
  }

  Set<String> _buildSearchCandidates(POIModel poi) {
    final name = _normalizeText(poi.name);
    final category = _normalizeText(_getCategoryName(context, poi.category));
    final acronym = _acronymFromName(name);
    final collapsedName = name.replaceAll(RegExp(r'\s+'), '');
    final collapsedCategory = category.replaceAll(RegExp(r'\s+'), '');

    return {
      name,
      category,
      acronym,
      collapsedName,
      collapsedCategory,
    }.where((value) => value.isNotEmpty).toSet();
  }

  String _acronymFromName(String normalizedName) {
    final ignore = {'de', 'da', 'do', 'dos', 'das', 'e', 'and'};
    final words = normalizedName
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.isNotEmpty && !ignore.contains(w))
        .toList();

    if (words.isEmpty) return '';
    return words.map((w) => w[0]).join();
  }

  String _normalizeText(String value) {
    final lower = value.toLowerCase();
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const to = 'aaaaaeeeeiiiiooooouuuucn';

    final out = StringBuffer();
    for (final rune in lower.runes) {
      final ch = String.fromCharCode(rune);
      final i = from.indexOf(ch);
      out.write(i >= 0 ? to[i] : ch);
    }

    return out.toString().trim();
  }

  String _getCategoryName(BuildContext context, String category) {
    final loc = AppLocalizations.of(context)!;
    switch (category.toLowerCase()) {
      case 'restroom':
        return loc.wc;
      case 'food':
      case 'bar':
      case 'restaurant':
        return loc.food;
      case 'emergency_exit':
        return loc.exit;
      case 'first_aid':
        return loc.firstAid;
      case 'information':
        return loc.information;
      case 'merchandise':
        return loc.merchandising;
      default:
        return category;
    }
  }
}
