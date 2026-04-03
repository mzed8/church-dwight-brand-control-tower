import 'package:flutter/material.dart';

/// A card that lifts and glows on hover.
/// Uses [MouseRegion] for web hover detection.
class ShiningCard extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final Color? glowColor;

  const ShiningCard({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.glowColor,
  });

  @override
  State<ShiningCard> createState() => _ShiningCardState();
}

class _ShiningCardState extends State<ShiningCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.identity()
          ..translateByDouble(0.0, _isHovered ? -4.0 : 0.0, 0.0, 1.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: [
            BoxShadow(
              color: (widget.glowColor ?? Colors.blue)
                  .withValues(alpha: _isHovered ? 0.2 : 0.06),
              blurRadius: _isHovered ? 24 : 8,
              spreadRadius: _isHovered ? 2 : 0,
              offset: Offset(0, _isHovered ? 8 : 2),
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}
