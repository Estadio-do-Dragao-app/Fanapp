import 'package:flutter/material.dart';

class CategoryButton extends StatelessWidget {
  final Widget icon; // pode ser Icon(...) ou Image(...)
  final VoidCallback onPressed;
  final double size;

  const CategoryButton({
    Key? key,
    required this.icon,
    required this.onPressed,
    this.size = 62,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bgColor = Color(0xFFD9D9D9);
    final shadowColor = Colors.black.withOpacity(0.15);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: shadowColor, blurRadius: 6, offset: Offset(0, 3)),
            ],
          ),
          alignment: Alignment.center,
          child: IconTheme(
            data: IconThemeData(size: 26), 
            child: icon,
          ),
        ),
      ),
    );
  }
}