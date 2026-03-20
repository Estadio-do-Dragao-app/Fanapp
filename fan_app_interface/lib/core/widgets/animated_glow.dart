import 'package:flutter/material.dart';

/// Um widget que aplica uma animação de pulsação (glow effect) 
/// nas suas bordas quando `play` transita para `true`.
class AnimatedSelectionGlow extends StatefulWidget {
  final Widget child;
  final bool play;
  final Duration duration;
  final Color glowColor;

  const AnimatedSelectionGlow({
    Key? key,
    required this.child,
    required this.play,
    this.duration = const Duration(milliseconds: 600),
    this.glowColor = const Color(0xFF929AD4),
  }) : super(key: key);

  @override
  State<AnimatedSelectionGlow> createState() => _AnimatedSelectionGlowState();
}

class _AnimatedSelectionGlowState extends State<AnimatedSelectionGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.play) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedSelectionGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.play && !oldWidget.play) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              if (_glowAnimation.value > 0)
                BoxShadow(
                  color: widget.glowColor.withOpacity(_glowAnimation.value * 0.8),
                  blurRadius: 12 * _glowAnimation.value,
                  spreadRadius: 2 * _glowAnimation.value,
                ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
