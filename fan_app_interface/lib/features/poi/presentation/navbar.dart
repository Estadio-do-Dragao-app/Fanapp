import 'package:flutter/material.dart';
import 'package:fan_app_interface/core/widgets/category_buttons.dart';
import 'package:fan_app_interface/features/hub/presentation/search_bar.dart';

/// Simple MapPage implementation that shows a placeholder 'map' area and a
/// horizontal row of category buttons overlayed at the top.
class Navbar extends StatefulWidget {
	const Navbar({Key? key}) : super(key: key);

	@override
	State<Navbar> createState() => _NavbarState();
}

class _NavbarState extends State<Navbar> {
	final List<String> categories = ['Seat','WC', 'Food', 'Exit'];
	int selected = 0;

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			backgroundColor: Colors.transparent,
			body: Stack(
				children: [
					Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF929AD4),Color(0xFF929AD4).withOpacity(0.8), Color(0xFF929AD4).withOpacity(0.5),Colors.transparent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

					// Top overlay: category buttons inside SafeArea
					SafeArea(
						child: Padding(
							padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
							child: Stack(
								children: [
									Align(
										alignment: Alignment.topLeft,
										child: Column(
											mainAxisSize: MainAxisSize.min,
											crossAxisAlignment: CrossAxisAlignment.start,
											children: [
												const Text(
													'Where to?',
													style: TextStyle(
														fontSize: 32,
									            fontFamily: 'Gabarito',
														fontWeight: FontWeight.bold,
													),
                          textAlign: TextAlign.left,
												),
												const SizedBox(height: 16),
												CategoryButtons(
													labels: categories,
													selectedIndex: selected,
													onSelect: (i) => setState(() => selected = i),
													iconBuilder: (label) {
														switch (label) {
															case 'Seat':
																return const Icon(Icons.event_seat, color: Colors.black);
															case 'WC':
																return const Icon(Icons.wc, color: Colors.black);
															case 'Food':
																return const Icon(Icons.fastfood, color: Colors.black);
															case 'Exit':
																return const Icon(Icons.meeting_room, color: Colors.black);
															default:
																return const Icon(Icons.help, color: Colors.black);
														}
													},
												),
											],
										),
									),
									// Search button in top right
								],
							),
						),
					),
				],
			),
		);
	}
}
