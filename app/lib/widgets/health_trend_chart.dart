import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../theme/brand_theme.dart';

/// Line chart displaying health score trend over 90 days.
/// Expects data with 'date' (String) and 'health_score' (num) keys.
class HealthTrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const HealthTrendChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('No health data available'));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sortedData = List<Map<String, dynamic>>.from(data)
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

    final spots = <FlSpot>[];
    for (var i = 0; i < sortedData.length; i++) {
      final score = double.tryParse(sortedData[i]['health_score'].toString()) ?? 0.0;
      spots.add(FlSpot(i.toDouble(), score));
    }

    // Build date labels — show ~5 evenly spaced labels
    final labelInterval =
        (sortedData.length / 5).ceil().clamp(1, sortedData.length);

    return Padding(
      padding: const EdgeInsets.only(top: 16, right: 16, bottom: 8),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (value) => FlLine(
              color: (isDark ? BrandColors.borderDark : BrandColors.border)
                  .withValues(alpha: 0.5),
              strokeWidth: 0.5,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: 25,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? BrandColors.textSecondaryDark
                        : BrandColors.textSecondary,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: labelInterval.toDouble(),
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= sortedData.length) {
                    return const SizedBox();
                  }
                  final dateStr = sortedData[idx]['date'] as String;
                  // Show month/day from date string
                  final parts = dateStr.split('-');
                  final label = parts.length >= 3
                      ? '${parts[1]}/${parts[2]}'
                      : dateStr;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? BrandColors.textSecondaryDark
                            : BrandColors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              // Critical threshold at 60
              HorizontalLine(
                y: 60,
                color: BrandColors.red.withValues(alpha: 0.6),
                strokeWidth: 1,
                dashArray: [6, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  style: TextStyle(
                    fontSize: 9,
                    color: BrandColors.red.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                  labelResolver: (_) => 'Critical (60)',
                ),
              ),
              // Watch threshold at 75
              HorizontalLine(
                y: 75,
                color: BrandColors.gold.withValues(alpha: 0.6),
                strokeWidth: 1,
                dashArray: [6, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  style: TextStyle(
                    fontSize: 9,
                    color: BrandColors.gold.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                  labelResolver: (_) => 'Watch (75)',
                ),
              ),
            ],
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) =>
                  isDark ? BrandColors.cardDark : Colors.white,
              tooltipBorder: BorderSide(
                color: isDark ? BrandColors.borderDark : BrandColors.border,
              ),
              tooltipRoundedRadius: 8,
              getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                final idx = spot.x.toInt();
                final date = idx < sortedData.length
                    ? sortedData[idx]['date'] as String
                    : '';
                return LineTooltipItem(
                  '$date\n',
                  TextStyle(
                    fontSize: 10,
                    color: isDark
                        ? BrandColors.textSecondaryDark
                        : BrandColors.textSecondary,
                  ),
                  children: [
                    TextSpan(
                      text: spot.y.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? BrandColors.textDark
                            : BrandColors.textPrimary,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              preventCurveOverShooting: true,
              color: BrandColors.blue,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    BrandColors.blue.withValues(alpha: 0.25),
                    BrandColors.blue.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      ),
    );
  }
}
