import 'package:flutter/material.dart';

/// A widget that wraps a child and adds a subtle pulsing glow effect behind it.
///
/// Used for KPI numbers and important metrics to draw attention.
class GlowPulse extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final double intensity;

  const GlowPulse({
    super.key,
    required this.child,
    this.glowColor = const Color(0xFF004B8D),
    this.intensity = 0.5,
  });

  @override
  State<GlowPulse> createState() => _GlowPulseState();
}

class _GlowPulseState extends State<GlowPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final opacity = 0.05 + (_animation.value * 0.15 * widget.intensity);
        final spread = 4.0 + (_animation.value * 12.0 * widget.intensity);
        final blur = 8.0 + (_animation.value * 20.0 * widget.intensity);

        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(alpha: opacity),
                blurRadius: blur,
                spreadRadius: spread,
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
