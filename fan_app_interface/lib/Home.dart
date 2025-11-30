import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'features/map/presentation/pages/map_page.dart';
import 'features/poi/presentation/navbar.dart';
import 'features/hub/presentation/search_bar.dart';
import 'features/hub/presentation/menu_button.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          const MapPage(),
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
                    return SearchBarBottomSheet();
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
                      child: const Icon(Icons.search, color: Colors.white, size: 30),
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