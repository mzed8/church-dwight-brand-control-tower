import 'package:flutter/material.dart';

/// A count-up number animation for KPI displays.
/// Smoothly animates between old and new values with easing.
class TickerNumber extends StatefulWidget {
  final double value;
  final String prefix;
  final String suffix;
  final int decimals;
  final TextStyle? style;
  final Duration duration;

  const TickerNumber({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.decimals = 0,
    this.style,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  State<TickerNumber> createState() => _TickerNumberState();
}

class _TickerNumberState extends State<TickerNumber>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _curved;
  double _oldValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(TickerNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _oldValue = oldWidget.value;
      _controller.forward(from: 0);
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
      animation: _curved,
      builder: (context, _) {
        final current =
            _oldValue + (widget.value - _oldValue) * _curved.value;
        return Text(
          '${widget.prefix}${current.toStringAsFixed(widget.decimals)}${widget.suffix}',
          style: widget.style,
        );
      },
    );
  }
}
