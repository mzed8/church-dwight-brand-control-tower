import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/brand.dart';
import '../theme/brand_theme.dart';
import 'shining_card.dart';
import 'ticker_number.dart';

/// A brand card for the portfolio grid.
/// Shows health score, delta, ROAS, and a mini sparkline.
class BrandCard extends StatelessWidget {
  final Brand brand;

  const BrandCard({super.key, required this.brand});

  Color get _statusColor {
    if (brand.healthScore > 75) return BrandColors.emerald;
    if (brand.healthScore >= 60) return BrandColors.gold;
    return BrandColors.red;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? BrandColors.textDark : BrandColors.textPrimary;
    final textSecondary =
        isDark ? BrandColors.textSecondaryDark : BrandColors.textSecondary;
    final cardBg = isDark ? BrandColors.cardDark : Colors.white;
    final borderColor = isDark ? BrandColors.borderDark : BrandColors.border;

    return GestureDetector(
      onTap: () => context.go('/brand/${brand.id}'),
      child: ShiningCard(
        glowColor: _statusColor,
        child: Container(
          width: 280,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Status accent bar on the left
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _statusColor.withValues(alpha: 0.8),
                        _statusColor.withValues(alpha: 0.2),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
                // Card content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Brand name
                        Text(
                          brand.name,
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Tagline
                        Text(
                          brand.tagline,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 16),
                        // Health score with circular indicator
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _HealthScoreRing(
                              score: brand.healthScore,
                              color: _statusColor,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Delta indicator
                                  _DeltaChip(
                                    delta: brand.healthDelta,
                                  ),
                                  const SizedBox(height: 6),
                                  // Avg ROAS
                                  Row(
                                    children: [
                                      Text(
                                        'Avg ROAS ',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: textSecondary,
                                        ),
                                      ),
                                      Text(
                                        '${brand.avgRoas.toStringAsFixed(2)}x',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Mini sparkline
                        SizedBox(
                          height: 40,
                          child: _MiniSparkline(
                            data: brand.healthTrend,
                            color: _statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular progress ring with animated health score in the center.
class _HealthScoreRing extends StatelessWidget {
  final double score;
  final Color color;

  const _HealthScoreRing({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? BrandColors.textDark : BrandColors.textPrimary;

    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 5,
              strokeCap: StrokeCap.round,
              color: color.withValues(alpha: 0.15),
            ),
          ),
          // Foreground ring
          SizedBox(
            width: 64,
            height: 64,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: score / 100),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return CircularProgressIndicator(
                  value: value,
                  strokeWidth: 5,
                  strokeCap: StrokeCap.round,
                  color: color,
                );
              },
            ),
          ),
          // Score number
          TickerNumber(
            value: score,
            decimals: 0,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Delta indicator chip: up/down arrow with points change.
class _DeltaChip extends StatelessWidget {
  final double delta;

  const _DeltaChip({required this.delta});

  @override
  Widget build(BuildContext context) {
    final isPositive = delta >= 0;
    final color = isPositive ? BrandColors.emerald : BrandColors.red;
    final arrow = isPositive ? '\u25B2' : '\u25BC';
    final bgColor = color.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$arrow ${delta.abs().toStringAsFixed(1)} pts',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Mini sparkline using fl_chart LineChart.
class _MiniSparkline extends StatelessWidget {
  final List<double> data;
  final Color color;

  const _MiniSparkline({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final spots = data
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        clipData: const FlClipData.all(),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: color,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.2),
                  color.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
