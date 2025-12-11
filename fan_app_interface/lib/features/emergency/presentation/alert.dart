import 'package:flutter/material.dart';
import '../../map/presentation/stadium_map_page.dart';
import 'package:fan_app_interface/l10n/app_localizations.dart';

class EmergencyAlertPage extends StatefulWidget {
  const EmergencyAlertPage({Key? key}) : super(key: key);

  @override
  State<EmergencyAlertPage> createState() => _EmergencyAlertPageState();
}

class _EmergencyAlertPageState extends State<EmergencyAlertPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Future<void> _autoRedirectFuture;

  @override
  void initState() {
    super.initState();
    
    // Animação de piscar (blink) para a borda vermelha
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);

    // Auto-redirect em 3 segundos
    _autoRedirectFuture = Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _goToMap();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _goToMap() {
    Navigator.of(context).pushReplacementNamed('/map');
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;


return Scaffold(
  body: FutureBuilder<void>(
    future: _autoRedirectFuture,
    builder: (context, snapshot) {
      final radius = MediaQuery.of(context).viewPadding.top > 0 ? 70.0 : 0.0; // curva do telemóvel

      return Stack(
        children: [
          // Fundo (mapa)
          Positioned.fill(
            child: StadiumMapPage(),
          ),

          // Borda vermelha ANIMADA (AGORA ocupa o ecrã INTEIRO)
          Positioned(
            top: -20,
            bottom: -20,
            left: -20,
            right: -20,
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(
                      color: Color(0xFFBD453D).withOpacity(
                        (_animationController.value ),
                      ),
                      width: 35,
                    ),
                  ),
                );
              },
            ),
          ),
          // Conteúdo respeita SafeArea — a BORDA NÃO
          SafeArea(
            child: Stack(
              children: [
                // Conteúdo central
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.15,
                  left: 1,
                  right: 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          color: Color(0xFFBD453D),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.warning_rounded,
                          color: Colors.white,
                          size: 150,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        localizations.evacuation,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Gabarito',
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),

                // Botão MAP
                Positioned(
                  bottom: 12,
                  left: 32,
                  right: 32,
                  child: GestureDetector(
                    onTap: _goToMap,
                    child: Container(
                      height: 94,
                      decoration: BoxDecoration(
                        color: const Color(0xFFBD453D),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          
                          children: [
                            const SizedBox(height: 20),
                            Text(
                                  localizations.map,
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontFamily: 'Gabarito',
                                  ),
                                ),
                              
                            const Text(
                              '3s',
                              style: TextStyle(
                                fontSize: 16,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.white70,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                          
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      );
    },
  ),
);
  }
}
