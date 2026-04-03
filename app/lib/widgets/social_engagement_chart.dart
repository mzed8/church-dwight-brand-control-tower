import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/brand_theme.dart';

/// Multi-line chart showing social engagement trends by platform.
class SocialEngagementChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const SocialEngagementChart({super.key, required this.data});

  static const _platformColors = {
    'Instagram': BrandColors.blue,
    'TikTok': BrandColors.emerald,
    'Twitter/X': BrandColors.gold,
    'Reddit': BrandColors.red,
  };

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('No social data available'));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor =
        isDark ? BrandColors.textSecondaryDark : BrandColors.textSecondary;

    // Group data by platform
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final row in data) {
      final platform = row['platform']?.toString() ?? 'Unknown';
      grouped.putIfAbsent(platform, () => []).add(row);
    }

    // Sort each platform's data by date
    for (final entries in grouped.values) {
      entries.sort((a, b) =>
          (a['date']?.toString() ?? '').compareTo(b['date']?.toString() ?? ''));
    }

    // Collect all unique sorted dates for the x-axis
    final allDates = <String>{};
    for (final entries in grouped.values) {
      for (final row in entries) {
        allDates.add(row['date']?.toString() ?? '');
      }
    }
    final sortedDates = allDates.toList()..sort();

    // Take last 30 dates
    final dates = sortedDates.length > 30
        ? sortedDates.sublist(sortedDates.length - 30)
        : sortedDates;
    final dateIndex = {
      for (var i = 0; i < dates.length; i++) dates[i]: i.toDouble()
    };

    // Build line data per platform
    double maxY = 0;
    final lines = <LineChartBarData>[];
    final activePlatforms = <String>[];
    final platformOrder = ['Instagram', 'TikTok', 'Twitter/X', 'Reddit'];

    for (final platform in platformOrder) {
      final entries = grouped[platform];
      if (entries == null || entries.isEmpty) continue;

      final color = _platformColors[platform] ?? BrandColors.blue;
      final spots = <FlSpot>[];

      for (final row in entries) {
        final date = row['date']?.toString() ?? '';
        final x = dateIndex[date];
        if (x == null) continue;
        final y =
            double.tryParse(row['total_engagement']?.toString() ?? '') ?? 0.0;
        spots.add(FlSpot(x, y));
        if (y > maxY) maxY = y;
      }

      if (spots.isEmpty) continue;
      spots.sort((a, b) => a.x.compareTo(b.x));
      activePlatforms.add(platform);

      lines.add(
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.25,
          color: color,
          barWidth: 2.5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: color.withValues(alpha: 0.08),
          ),
        ),
      );
    }

    if (lines.isEmpty) {
      return const Center(child: Text('No engagement data'));
    }

    // Round maxY up for nice axis
    final yInterval = _niceInterval(maxY);
    final adjustedMaxY = (maxY / yInterval).ceil() * yInterval;

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8, top: 8),
            child: LineChart(
              LineChartData(
                lineBarsData: lines,
                minX: 0,
                maxX: (dates.length - 1).toDouble(),
                minY: 0,
                maxY: adjustedMaxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yInterval,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: (isDark ? BrandColors.borderDark : BrandColors.border)
                        .withValues(alpha: 0.5),
                    strokeWidth: 0.5,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      interval: yInterval,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox();
                        return Text(
                          _formatNumber(value),
                          style:
                              TextStyle(fontSize: 10, color: secondaryColor),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval:
                          (dates.length / 5).ceilToDouble().clamp(1, 30),
                      getTitlesWidget: (value, meta) {
                        final idx = value.round();
                        if (idx < 0 || idx >= dates.length) {
                          return const SizedBox();
                        }
                        final date = dates[idx];
                        // Show as MM/DD
                        final parts = date.split('-');
                        final label = parts.length >= 3
                            ? '${parts[1]}/${parts[2]}'
                            : date;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            label,
                            style: TextStyle(
                                fontSize: 9, color: secondaryColor),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) =>
                        isDark ? BrandColors.cardDark : Colors.white,
                    tooltipBorder: BorderSide(
                      color: isDark
                          ? BrandColors.borderDark
                          : BrandColors.border,
                    ),
                    getTooltipItems: (spots) => spots.map((spot) {
                      final platform =
                          activePlatforms.length > spot.barIndex
                              ? activePlatforms[spot.barIndex]
                              : '';
                      final color =
                          _platformColors[platform] ?? BrandColors.blue;
                      return LineTooltipItem(
                        '$platform\n${_formatNumber(spot.y)}',
                        TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Legend
        Wrap(
          spacing: 16,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            for (final platform in platformOrder)
              if (grouped.containsKey(platform))
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _platformColors[platform],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      platform,
                      style:
                          TextStyle(fontSize: 11, color: secondaryColor),
                    ),
                  ],
                ),
          ],
        ),
      ],
    );
  }

  static double _niceInterval(double maxVal) {
    if (maxVal <= 0) return 1;
    final rough = maxVal / 5;
    final mag =
        _pow10((rough.toString().split('.').first.length - 1).toDouble());
    return (rough / mag).ceil() * mag;
  }

  static double _pow10(double exp) {
    double result = 1;
    for (int i = 0; i < exp.toInt(); i++) {
      result *= 10;
    }
    return result;
  }

  static String _formatNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return value.toStringAsFixed(0);
  }
}
