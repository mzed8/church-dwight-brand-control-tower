import 'package:flutter/material.dart';
import '../theme/brand_theme.dart';

/// A channel spend slider that shows current vs proposed values
/// with a delta indicator colored green (increase) or red (decrease).
class SpendSlider extends StatelessWidget {
  final String channel;
  final double currentValue;
  final double proposedValue;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const SpendSlider({
    super.key,
    required this.channel,
    required this.currentValue,
    required this.proposedValue,
    this.min = 0,
    this.max = 100000,
    required this.onChanged,
  });

  static String _formatCurrency(double value) {
    if (value >= 1000000) {
      final m = value / 1000000;
      return '\$${m.toStringAsFixed(m.truncateToDouble() == m ? 0 : 1)}M';
    }
    if (value >= 1000) {
      final k = value / 1000;
      return '\$${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1)}K';
    }
    return '\$${value.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final delta = proposedValue - currentValue;
    final isPositive = delta >= 0;

    final primaryText = isDark ? BrandColors.textDark : BrandColors.textPrimary;
    final mutedText =
        isDark ? BrandColors.textSecondaryDark : BrandColors.textSecondary;
    final deltaColor = isPositive ? BrandColors.emerald : BrandColors.red;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Channel name row with current and delta
          Row(
            children: [
              Expanded(
                child: Text(
                  channel,
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _formatCurrency(currentValue),
                style: TextStyle(
                  color: mutedText,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward,
                size: 12,
                color: mutedText,
              ),
              const SizedBox(width: 8),
              Text(
                _formatCurrency(proposedValue),
                style: TextStyle(
                  color: primaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: deltaColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${isPositive ? "\u25B2" : "\u25BC"}${_formatCurrency(delta.abs())}',
                  style: TextStyle(
                    color: deltaColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Slider
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: BrandColors.blue,
              inactiveTrackColor:
                  isDark ? BrandColors.borderDark : BrandColors.border,
              thumbColor: BrandColors.blue,
              overlayColor: BrandColors.blue.withValues(alpha: 0.12),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: proposedValue.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
