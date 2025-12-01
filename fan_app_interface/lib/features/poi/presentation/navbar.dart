import 'package:flutter/material.dart';
import 'package:fan_app_interface/core/widgets/category_buttons.dart';
import 'package:fan_app_interface/features/poi/presentation/destination_selection.dart';
import 'package:fan_app_interface/l10n/app_localizations.dart';

/// Simple MapPage implementation that shows a placeholder 'map' area and a
/// horizontal row of category buttons overlayed at the top.
class Navbar extends StatefulWidget {
	const Navbar({Key? key}) : super(key: key);

	@override
	State<Navbar> createState() => _NavbarState();
}

class _NavbarState extends State<Navbar> {
	final List<String> categoryIds = ['seat','wc', 'food', 'exit'];
	int selected = 0;

	@override
	Widget build(BuildContext context) {
		final localizations = AppLocalizations.of(context)!;
		final categories = [
			localizations.seat,
			localizations.wc,
			localizations.food,
			localizations.exit,
		];

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
												Text(
													localizations.whereToQuestion,
													style: const TextStyle(
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
													onSelect: (i) {
														setState(() => selected = i);
														Navigator.push(
															context,
															PageRouteBuilder(
																pageBuilder: (context, animation, secondaryAnimation) => DestinationSelectionPage(
																	categoryId: categoryIds[i],
																),
																transitionsBuilder: (context, animation, secondaryAnimation, child) {
																	const begin = Offset(0.0, 1.0);
																	const end = Offset.zero;
																	const curve = Curves.easeInOut;
																	final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
																	final offsetAnimation = animation.drive(tween);
																	return SlideTransition(
																		position: offsetAnimation,
																		child: child,
																	);
																},
															),
														);
													},
													iconBuilder: (label) {
														// Match against translated labels
														if (label == localizations.seat) {
															return const Icon(Icons.event_seat, color: Colors.black);
														} else if (label == localizations.wc) {
															return const Icon(Icons.wc, color: Colors.black);
														} else if (label == localizations.food) {
															return const Icon(Icons.fastfood, color: Colors.black);
														} else if (label == localizations.exit) {
															return const Icon(Icons.meeting_room, color: Colors.black);
														} else {
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
