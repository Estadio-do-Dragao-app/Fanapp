import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'features/map/presentation/pages/map_page.dart';
import 'features/poi/presentation/navbar.dart';
import 'features/hub/presentation/search_bar.dart';
import 'features/hub/presentation/menu_button.dart';
import 'features/map/presentation/filter_button.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  // GlobalKey para acessar o state do MapPage (agora público)
  final GlobalKey<MapPageState> _mapPageKey = GlobalKey<MapPageState>();

  // Estado do heatmap
  bool _showHeatmap = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          MapPage(key: _mapPageKey, showHeatmap: _showHeatmap),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 240,
              color: Colors.transparent,
              child: const Navbar(),
            ),
          ),
          // Filter button - top right below navbar
          Positioned(
            top: MediaQuery.of(context).padding.top + 100,
            right: 16,
            child: FilterButton(
              showHeatmap: _showHeatmap,
              onHeatmapChanged: (value) {
                setState(() {
                  _showHeatmap = value;
                });
              },
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 92,
            child: GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  isDismissible: true,
                  enableDrag: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  builder: (context) {
                    return SearchBarBottomSheet(
                      onPOISelected: (poi) {
                        // Fazer zoom no POI após fechar a barra de pesquisa
                        _mapPageKey.currentState?.zoomToPOI(poi);
                      },
                    );
                  },
                );
              },
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF161A3E),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
                      child: const Icon(
                        Icons.search,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.search,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Gabarito',
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: MenuButton(
              onTap: () {
                // Action for menu button tap
              },
            ),
          ),
        ],
      ),
    );
  }
}
