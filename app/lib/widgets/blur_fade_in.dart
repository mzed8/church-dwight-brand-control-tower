import 'dart:ui';
import 'package:flutter/material.dart';

/// A widget that fades in with a blur-clearing and upward-slide effect.
class BlurFadeIn extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;

  const BlurFadeIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.delay = Duration.zero,
  });

  @override
  State<BlurFadeIn> createState() => _BlurFadeInState();
}

class _BlurFadeInState extends State<BlurFadeIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final blur = 8.0 * (1 - _controller.value);
        return Opacity(
          opacity: _controller.value,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Transform.translate(
              offset: Offset(0, 12 * (1 - _controller.value)),
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
