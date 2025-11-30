import 'package:flutter/material.dart';
import 'package:fan_app_interface/core/widgets/category_button.dart';

/// Horizontal list of CategoryButton widgets.
class CategoryButtons extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Widget Function(String label) iconBuilder;

  const CategoryButtons({
    Key? key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelect,
    required this.iconBuilder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(labels.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: CategoryButton(
              icon: iconBuilder(labels[i]),
              size: 56,
              onPressed: () => onSelect(i),
            ),
          );
        }),
      ),
    );
  }
}
