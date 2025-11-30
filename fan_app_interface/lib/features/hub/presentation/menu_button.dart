import 'package:flutter/material.dart';

class MenuButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;
  final Color backgroundColor;
  final Color dotColor;
  final EdgeInsets padding;

  const MenuButton({
    Key? key,
    required this.onTap,
    this.size = 60,
    this.backgroundColor = const Color(0xFF161A3E),
    this.dotColor = Colors.white,
    this.padding = const EdgeInsets.all(0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: Container(
        width: size,
        height: size,
        padding: padding,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          Icons.more_vert,
          color: dotColor,
          size: 30,
        ),
      ),
    );
  }
}
