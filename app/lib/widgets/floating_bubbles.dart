import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/brand_theme.dart';

/// A bubble particle for the floating background effect.
class _Bubble {
  double x;
  double y;
  final double radius;
  final double speed;
  final Color color;
  final double driftAmplitude;
  final double driftFrequency;
  final double phase;
  final double baseX;

  _Bubble({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.color,
    required this.driftAmplitude,
    required this.driftFrequency,
    required this.phase,
  }) : baseX = x;
}

/// Animated floating bubbles/particles as a background layer.
///
/// Place this as the first child of a [Stack] so it renders behind content.
class FloatingBubbles extends StatefulWidget {
  final bool isDark;
  const FloatingBubbles({super.key, this.isDark = true});

  @override
  State<FloatingBubbles> createState() => _FloatingBubblesState();
}

class _FloatingBubblesState extends State<FloatingBubbles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<_Bubble> _bubbles;
  final _rand = Random();

  @override
  void initState() {
    super.initState();
    _bubbles = [];
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_Bubble> _generateBubbles(Size size) {
    final count = 18;
    final colors = widget.isDark
        ? [
            BrandColors.blue.withValues(alpha: 0.25),
            BrandColors.gold.withValues(alpha: 0.20),
            BrandColors.emerald.withValues(alpha: 0.20),
            BrandColors.red.withValues(alpha: 0.15),
          ]
        : [
            BrandColors.blue.withValues(alpha: 0.15),
            BrandColors.gold.withValues(alpha: 0.12),
            BrandColors.emerald.withValues(alpha: 0.12),
            BrandColors.red.withValues(alpha: 0.10),
          ];

    return List.generate(count, (_) {
      final radius = 8.0 + _rand.nextDouble() * 24.0;
      return _Bubble(
        x: _rand.nextDouble() * size.width,
        y: _rand.nextDouble() * size.height,
        radius: radius,
        speed: 0.15 + _rand.nextDouble() * 0.45,
        color: colors[_rand.nextInt(colors.length)],
        driftAmplitude: 10.0 + _rand.nextDouble() * 30.0,
        driftFrequency: 0.3 + _rand.nextDouble() * 0.7,
        phase: _rand.nextDouble() * 2.0 * pi,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (_bubbles.isEmpty && size.width > 0 && size.height > 0) {
          _bubbles = _generateBubbles(size);
        }
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // Update positions
            for (final b in _bubbles) {
              b.y -= b.speed;
              b.x = b.baseX + sin(b.y * b.driftFrequency * 0.01 + b.phase) * b.driftAmplitude;

              // Wrap around when off top
              if (b.y + b.radius < 0) {
                b.y = size.height + b.radius;
              }
              // Keep x in bounds loosely
              if (b.x < -b.radius * 2) {
                b.x = size.width + b.radius;
              } else if (b.x > size.width + b.radius * 2) {
                b.x = -b.radius;
              }
            }
            return CustomPaint(
              size: size,
              painter: _BubblePainter(bubbles: _bubbles),
            );
          },
        );
      },
    );
  }
}

class _BubblePainter extends CustomPainter {
  final List<_Bubble> bubbles;
  _BubblePainter({required this.bubbles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in bubbles) {
      final paint = Paint()
        ..color = b.color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, b.radius * 0.5);
      canvas.drawCircle(Offset(b.x, b.y), b.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BubblePainter old) => true;
}
