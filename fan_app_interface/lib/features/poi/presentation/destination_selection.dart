import 'package:flutter/material.dart';
import 'package:fan_app_interface/l10n/app_localizations.dart';


class LocationOption {
  final String name;
  final int distance; // metros
  final int time; // minutos
  final bool isFaster;
  LocationOption(this.name, this.distance, this.time, {this.isFaster = false});
}

class DestinationSelectionPage extends StatefulWidget {
  final String categoryId;
  const DestinationSelectionPage({Key? key, required this.categoryId}) : super(key: key);

  @override
  State<DestinationSelectionPage> createState() => _DestinationSelectionPageState();
}

class _DestinationSelectionPageState extends State<DestinationSelectionPage> {
  int? selectedIndex;
  
  @override
  void initState() {
    super.initState();
    // Pré-seleciona o item com isFaster: true
    _initializeSelection();
  }
  
  void _initializeSelection() {
    final options = _getOptions();
    for (int i = 0; i < options.length; i++) {
      if (options[i].isFaster) {
        selectedIndex = i;
        break;
      }
    }
  }
  
  List<LocationOption> _getOptions() {
    switch (widget.categoryId) {
      case 'wc':
        return wcOptions;
      case 'seat':
        return seatOptions;
      case 'food':
        return foodOptions;
      case 'exit':
        return exitOptions;
      default:
        return [];
    }
  }
  
  // Dados para cada categoria
  static final List<LocationOption> wcOptions = [
    LocationOption('WC 1', 50, 3, isFaster: true),
    LocationOption('WC 2', 150, 9),
    LocationOption('WC 3', 100, 2),
  ];

  static final List<LocationOption> seatOptions = [
    LocationOption('Seat 101', 120, 5, isFaster: true),
  ];

  static final List<LocationOption> foodOptions = [
    LocationOption('Central Restaurant', 80, 4, isFaster: true),
    LocationOption('Dragon\'s Pizzeria', 200, 10),
    LocationOption('Sushi Bar', 150, 7),
  ];

  static final List<LocationOption> exitOptions = [
    LocationOption('North Exit', 60, 3, isFaster: true),
    LocationOption('South Exit', 180, 8),
    LocationOption('East Exit', 140, 6),
  ];

  static IconData getCategoryIcon(String categoryId) {
    switch (categoryId) {
      case 'seat': return Icons.event_seat;
      case 'wc': return Icons.wc;
      case 'food': return Icons.fastfood;
      case 'exit': return Icons.meeting_room;
      default: return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    
    // Seleciona os dados conforme a categoria
    final options = _getOptions();

    return Scaffold(
      backgroundColor: const Color(0xFF161A3E),
      body: Stack(
        children: [
          // Mapa ocupa 40% superior
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.4,
            child: Container(
              color: Colors.grey[300],
              child: Center(
                child: Text(
                  'MAP PLACEHOLDER',
                  style: TextStyle(color: Colors.grey[600], fontSize: 18),
                ),
              ),
            ),
          ),
          
          // Botão voltar no canto superior esquerdo
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Color(0xFF161A3E),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          
          // Lista ocupa 60% inferior
          Positioned(
            top: MediaQuery.of(context).size.height * 0.38,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF161A3E),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  // Título "Choose a location"
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      localizations.chooseLocation,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Gabarito',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(color: Colors.white24, thickness: 1),
                  
                  // Lista de opções
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options[index];
                        final isSelected = selectedIndex == index;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                selectedIndex = index;
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF161A3E),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected 
                                    ? Colors.white 
                                    :  Colors.white24,
                                  width: isSelected ? 3 : (option.isFaster ? 2 : 1),
                                ),
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(getCategoryIcon(widget.categoryId), color: Colors.white, size: 32),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          option.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Gabarito',
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            const Icon(Icons.groups, color: Colors.white, size: 16),
                                            const SizedBox(width: 4),
                                            Text(
                                              localizations.minutes(option.time),
                                              style: const TextStyle(color: Colors.white),
                                            ),
                                            if (option.isFaster)
                                              Container(
                                                margin: const EdgeInsets.only(left: 8),
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.blueAccent,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  localizations.faster,
                                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${option.distance}m',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Botão "Choose location" fixo no fundo
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedIndex != null ? Colors.indigo[200] : Colors.grey[600],
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: selectedIndex != null 
                ? () {
                    final selectedOption = options[selectedIndex!];
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(localizations.selected(selectedOption.name)),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    Navigator.pop(context);
                  }
                : null,
              child: Text(
                localizations.chooseLocationButton,
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}