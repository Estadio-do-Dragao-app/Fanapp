import 'package:flutter/material.dart';
import 'package:fan_app_interface/l10n/app_localizations.dart';

class SearchBarBottomSheet extends StatefulWidget {
  const SearchBarBottomSheet({Key? key}) : super(key: key);

  @override
  State<SearchBarBottomSheet> createState() => _SearchBarBottomSheetState();
}

class _SearchBarBottomSheetState extends State<SearchBarBottomSheet> {
  late TextEditingController _searchController;

  // Nomes dos restaurantes/bares (não traduzem)
  static const List<String> items = [
    'Restaurante Central',
    'Café Bem-vindo',
    'Pizzaria Do Dragão',
    'Sushi Bar',
    'Hamburgueria Premium',
    'Pastelaria Clássica',
    'Churrasqueira do Dragão',
    'Comida Italiana',
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setModalState) {
        final filteredItems = _searchController.text.isEmpty
            ? items
            : items
                .where((item) => item
                    .toLowerCase()
                    .contains(_searchController.text.toLowerCase()))
                .toList();

        return FractionallySizedBox(
          heightFactor: 1.0,
          child: Column(
            children: [
              // Search Bar
              Container(
                height: 60,
                margin: const EdgeInsets.all(16),
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
                    const SizedBox(width: 12),
                     Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
                      child: const Icon(Icons.search, color: Colors.white, size: 30),
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
                        ),
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context)!.search,
                          hintStyle: TextStyle(
                            color: Colors.white70,
                            fontFamily: 'Gabarito',
                            fontSize: 20,
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
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setModalState(() {});
                        },
                        child: const Icon(Icons.clear,
                            color: Colors.white, size: 30),
                      ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
              // Results List
              Expanded(
                child: ListView.builder(
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    final textColor = const Color(0xFF161A3E);

                    return ListTile(
                      title: Text(
                        item,
                        style: TextStyle(
                          fontFamily: 'Gabarito',
                          fontSize: 16,
                          color: textColor,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppLocalizations.of(context)!.selected(item))),
                        );
                      },
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
}